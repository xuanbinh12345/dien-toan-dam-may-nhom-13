SELECT
    count(*) AS row_count,
    md5(
        COALESCE(
            string_agg(row_to_json(t)::text, E'\n' ORDER BY order_id),
            ''
        )
    ) AS checksum_md5
FROM (
    SELECT order_id, amount,
           created_at AT TIME ZONE 'UTC' AS created_at_utc
    FROM public.orders
) AS t;
