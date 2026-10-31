use role STUDENT_CRICKET;  /* Use your own role STUDENT_{ANIMAL}, e.g. STUDENT_TIGER */
use warehouse mqe_wh_xs; 
select *
from MQE.ECON443.ECOMMERCE_TRAFFIC; /* first used limit 10; to see first ten rows of the table to get familiar */

/* 1. Overall conversion rate.
Regardless of which specific items are involved, what fraction of sessions result in a sale? A session is "converted" if it has at least one step3_checkout row. Conversion rate = (number of distinct sessions with at least one checkout) / (number of distinct sessions, with or without checkout). */

select
count(distinct case
when pagename = 'step3_checkout' then concat(customer_key, '_', session_uid)
end)
/count (distinct concat(customer_key, '_', session_uid)) as conversion_rate
from MQE.ECON443.ECOMMERCE_TRAFFIC;

/* 0.221 is the fraction of sessions result in a sale ! */

/* 2. Consideration-set heat map.
Customers often compare several items before deciding (some items are complements, some are substitutes). Build a two-way table across all 100 items: whenever two items i and j both appear at least once in the same (customer_key, session_uid) -- on any page -- increase the (i, j) cell by 1. The result is a heat map of item-pair co-occurrence that shows which items are frequently considered together. To create the heat map, you may need to use Excel Pivot Table function and "Color Scales" of Conditional Formating. */

select
first.item_sku as item_i,
second.item_sku as item_j,
count(distinct concat(first.customer_key, '_', first.session_uid)) as heat_map_value
from MQE.ECON443.ECOMMERCE_TRAFFIC as first
join MQE.ECON443.ECOMMERCE_TRAFFIC as second
    on first.customer_key = second.customer_key
    and first.session_uid = second.session_uid
    and item_i != item_j
group by item_i, item_j
order by item_i asc, item_j asc;


/* 100 x 100 matrix should have 10,000 cells, i only have 9,644. is it possible that some item pairs just don't occur together in our dataset? To check, count distinct items */
select count(distinct item_sku) as unique_items
from MQE.ECON443.ECOMMERCE_TRAFFIC; 
/* outputs 100 unique items, so we're good to create the pivot table! */

 /* 3. Cross-sell lift.
A common pricing/marketing strategy uses one item to help sell another: selling item i (sometimes at a discount) can increase sales of item j more than selling item j alone, i.e. P(purchase j | purchase i) > P(purchase j). Use the following definitions, each based on distinct sessions (not raw click counts):
  -P(purchase i) = (# sessions where item i appears in step3_checkout) / (# sessions where item i appears in step1_browse)
  
  -P(purchase i, j) = (# sessions where both i and j appear in step3_checkout) / (# sessions where both i and j appear in step1_browse)
  
 -P(purchase j | purchase i) = P(purchase i, j) / P(purchase i)

For every item j, find the item i (i != j) that gives it the largest "boosting effect" -- i.e., the largest P(purchase j | purchase i) relative to the baseline P(purchase j). */

with browse as (
    select distinct customer_key, session_uid, item_sku
    from MQE.ECON443.ECOMMERCE_TRAFFIC
    where pagename = 'step1_browse'
),
checkout as (
    select distinct customer_key, session_uid, item_sku
    from MQE.ECON443.ECOMMERCE_TRAFFIC
    where pagename = 'step3_checkout' /* identify items that were purchased */
),
individual_purchase_prob as (
    select
        browse.item_sku, 
        count(*) as browse_sessions,
        count(checkout.item_sku) as checkout_sessions,
        count(checkout.item_sku)/nullif(count (*), 0) as purchase_prob
    from browse
    left join checkout
        on browse.customer_key = checkout.customer_key
        and browse.session_uid = checkout.session_uid
        and browse.item_sku = checkout.item_sku
    group by browse.item_sku /*find purchase prob for each item */
),
item_pairs_browse as (
    select
        i.item_sku as item_i,
        j.item_sku as item_j,
        count(*) as both_browse_sessions
    from browse i 
    join browse j
        on i.customer_key = j.customer_key
        and i.session_uid = j.session_uid
        and i.item_sku <> j.item_sku
    group by i.item_sku, j.item_sku /*count the items that were browsed together */
        
),
item_pairs_checkout as (
    select
        i.item_sku as item_i,
        j.item_sku as item_j,
        count(*) as both_checkout_sessions
    from checkout i 
    join checkout j
        on i.customer_key = j.customer_key
        and i.session_uid = j.session_uid
        and i.item_sku <> j.item_sku
    group by i.item_sku, j.item_sku /*count the items that were checked out together */
),
pair_purchase_prob as (
    select
        browse.item_i,
        browse.item_j,
        coalesce(checkout.both_checkout_sessions, 0)
        / nullif(browse.both_browse_sessions, 0) as joint_purchase_prob
    from item_pairs_browse as browse
    left join item_pairs_checkout as checkout
        on browse.item_i = checkout.item_i
        and browse.item_j = checkout.item_j /*calculate their joint prob */
),
cross_purchase_prob as (
    select
        pair.item_i,
        pair.item_j,
        pair.joint_purchase_prob,
        i.purchase_prob as purchase_prob_i,
        j.purchase_prob as purchase_prob_j,
        pair.joint_purchase_prob/nullif(i.purchase_prob, 0) as conditional_purchase_prob
    from pair_purchase_prob as pair
    join individual_purchase_prob as i 
        on pair.item_i = i.item_sku
    join individual_purchase_prob as j
        on pair.item_j = j.item_sku /* compares individual and joint */
),
boost as (
    select
        item_i,
        item_j,
        conditional_purchase_prob,
        purchase_prob_j,
        conditional_purchase_prob/nullif(purchase_prob_j, 0) as boost_effect
    from cross_purchase_prob 
)
select
    boost.item_j,
    boost.item_i as best_booster,
    boost.purchase_prob_j,
    boost.conditional_purchase_prob,
    boost.boost_effect
from boost
where boost.boost_effect = (
    select max(boost_alt.boost_effect)
    from boost as boost_alt
    where boost_alt.item_j = boost.item_j
)
order by boost.item_j; /*find the best booster  */
