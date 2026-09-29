# GoMate V11 Canonical Place Catalog Alignment

Updated: 2026-09-20

## Scope

This step standardizes `tour_places_v11.csv` into a version-controlled canonical Place catalog for Backend, Map, Trip, and AI usage.

No database table, Flyway migration, Auth code, Map code, Route code, or Cloudinary upload was changed in this step.

## Source

Input file:

```text
C:\Users\PC\Downloads\tour_places_v11.csv
```

The source dataset is occurrence-based. The same real-world place appears in many tour rows, so it must not be imported one row per Place.

Canonical identity:

```text
destination_key + ten_diem_den_chuan
```

## Output Files

Canonical backend catalog:

```text
backend/src/main/resources/data/place_catalog_v11.csv
```

AI sharing catalog:

```text
backend/src/main/resources/data/ai_place_catalog_v11.csv
```

The AI file intentionally contains only:

```text
external_id, canonical_name, destination_key
```

This keeps Backend and AI aligned without creating another database table.

## External ID Convention

`external_source` is fixed:

```text
tour_places_v11
```

`external_id` is deterministic:

```text
{destination_key}:{normalized_canonical_name_slug}
```

Examples:

```text
da_lat:ho_xuan_huong
da_lat:thien_vien_truc_lam
da_nang_hue_hoi_an:pho_co_hoi_an
```

Rules:

- do not use PostgreSQL `places.id` as `external_id`;
- keep `destination_key` in the ID because the same name could become ambiguous across future destination scopes;
- preserve Vietnamese display text in `canonical_name`;
- use the slug only as a stable machine identifier.

## Validation Summary

Source rows:

```text
3067
```

Unique canonical places:

```text
188
```

Repeated tour occurrences collapsed:

```text
2879
```

Required identity fields:

```text
external_source, external_id, destination_key, canonical_name
```

Validation result:

```text
catalog rows: 188
AI rows: 188
unique external_id: 188
blank required identity fields: 0
```

## Unique Place Count By Destination

| destination_key | source rows | unique canonical places |
|---|---:|---:|
| da_lat | 812 | 63 |
| da_nang_hue_hoi_an | 1147 | 31 |
| ha_noi | 557 | 33 |
| phan_thiet | 292 | 22 |
| vung_tau | 259 | 39 |

## Duplicate And Anomaly Notes

Exact duplicate source rows:

```text
0
```

Blank `destination_key`:

```text
0
```

Blank `ten_diem_den_chuan`:

```text
0
```

Same `ten_diem_den_chuan` appearing across multiple `destination_key` values:

```text
0
```

Canonical identities with multiple raw source names:

```text
57
```

Representative examples:

| canonical identity | raw variants |
|---|---|
| da_nang_hue_hoi_an, Phố Cổ Hội An | hội an, hội an city, phố cổ hội an |
| da_nang_hue_hoi_an, Bà Nà Hills | bà nà, bà nà hills, núi chúa |
| ha_noi, Vịnh Hạ Long | hạ long, vịnh hạ long |
| da_lat, Quảng Trường Lâm Viên | lam vien, quảng trường lâm viên |
| da_lat, Langbiang | lang biang, langbiang, núi langbiang |
| phan_thiet, Đồi Cát Bay | cồn cát đỏ, đồi cát bay, đồi cát đỏ, đồi cát hồng, đồi cát mũi né |

These are expected synonym/normalization cases, not separate Places.

## Metadata Policy

The v11 source file does not contain category, province, district, address, latitude, longitude, or image/license fields.

For unknown fields, the catalog leaves values blank instead of inventing data.

Only the 5 Da Lat places already present in PostgreSQL were enriched from the existing checked seed data:

```text
Quảng Trường Lâm Viên
Hồ Xuân Hương
Dinh Bảo Đại
Thiền Viện Trúc Lâm
Hồ Tuyền Lâm
```

This enrichment copies existing seed metadata only. It does not upload media and does not modify production rows.

## Existing PostgreSQL Place Mapping

Current DB source IDs are from the earlier seed step:

```text
external_source = kpdl_candidate_v11
external_id = da-lat-...
```

Canonical V11 IDs are:

| places.id | DB name | current DB external_id | canonical external_id |
|---:|---|---|---|
| 2 | Quảng Trường Lâm Viên | da-lat-quang-truong-lam-vien | da_lat:quang_truong_lam_vien |
| 3 | Hồ Xuân Hương | da-lat-ho-xuan-huong | da_lat:ho_xuan_huong |
| 6 | Dinh Bảo Đại | da-lat-dinh-bao-dai | da_lat:dinh_bao_dai |
| 7 | Thiền Viện Trúc Lâm | da-lat-thien-vien-truc-lam | da_lat:thien_vien_truc_lam |
| 8 | Hồ Tuyền Lâm | da-lat-ho-tuyen-lam | da_lat:ho_tuyen_lam |

Important for the next import task:

- do not insert these 5 places again;
- match by canonical identity first: `destination_key + canonical_name`;
- then reconcile/update external source metadata in a controlled preview/diff if approved;
- do not rely only on current DB `external_source + external_id`, because those IDs were created before the V11 canonical convention.

## Next Step

After review approval, the next task can implement an import preview/diff:

```text
place_catalog_v11.csv
-> compare against PostgreSQL places
-> show insert/update/no-op decisions
-> import Da Lat first
-> then process other destination_key batches
```

Cloudinary upload remains out of scope until a later enrich/import task with reviewed image sources and licenses.
