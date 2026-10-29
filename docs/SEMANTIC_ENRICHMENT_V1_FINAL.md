# Semantic Enrichment V1 FINAL

Updated: 2026-10-01T06:43:53.970516+00:00

## Scope

This is the final `semantic-v1` data release for AI handoff. It enriches Place semantic profiles without changing schema, migrations, Auth, Flutter, Trip, Route, or Cloudinary.

No external web sources were used in this pass. Evidence comes from the version-controlled canonical catalog fields, conservative category rules, catalog-name rules, and a small set of documented manual review overrides for well-known examples.

## Result

| Metric | Count |
|---|---:|
| Canonical Place | 188 |
| READY | 114 |
| PARTIAL | 65 |
| NEED_REVIEW | 9 |
| Runtime eligible | 146 |
| Runtime ineligible | 42 |
| Place-tag links | 831 |
| Average tags / Place | 4.42 |
| Median tags / Place | 4.0 |

## Before / After

| Status | Before | After |
|---|---:|---:|
| READY | 71 | 114 |
| PARTIAL | 110 | 65 |
| NEED_REVIEW | 7 | 9 |

## Runtime Breakdown

146 runtime-eligible Place:

```json
{
  "NEED_REVIEW": 8,
  "PARTIAL": 50,
  "READY": 88
}
```

42 runtime-ineligible Place:

```json
{
  "NEED_REVIEW": 1,
  "PARTIAL": 15,
  "READY": 26
}
```

## Evidence Distribution

```json
{
  "CATALOG_NAME_RULE": 391,
  "CATEGORY_RULE": 431,
  "MANUAL_REVIEW": 9
}
```

## Weight Distribution

```json
{
  "0.3": 8,
  "0.6": 220,
  "0.8": 377,
  "1.0": 226
}
```

## Tag Coverage Top

```json
{
  "photo_spot": 107,
  "scenic": 86,
  "nature": 85,
  "cultural": 61,
  "iconic": 59,
  "heritage": 58,
  "historical": 58,
  "landmark": 52,
  "relaxing": 47,
  "beach": 25,
  "lake": 21,
  "local": 19,
  "countryside": 19,
  "local_culture": 19,
  "social": 16,
  "walking_area": 16,
  "mountain": 14,
  "waterfall": 12,
  "food": 9,
  "group_friendly": 8
}
```

## Interest Coverage

| interest_code | matching_place_count | runtime_matching_place_count | avg_semantic_match |
|---|---:|---:|---:|
| `NGHI_DUONG` | 92 | 74 | 1.518 |
| `KET_BAN` | 28 | 19 | 0.725 |
| `CHECKIN_HOT` | 135 | 103 | 1.476 |
| `THIEN_NHIEN` | 90 | 73 | 1.714 |
| `VAN_HOA` | 64 | 53 | 2.357 |
| `AM_THUC` | 24 | 19 | 0.85 |

## Category Coverage

| category | place_count | ready_count | partial_count | need_review_count | avg_tags_per_place |
|---|---:|---:|---:|---:|---:|
| `food` | 6 | 4 | 0 | 2 | 5.5 |
| `heritage` | 51 | 13 | 38 | 0 | 3.84 |
| `lake` | 21 | 14 | 0 | 7 | 5.86 |
| `landmark` | 52 | 29 | 23 | 0 | 4.06 |
| `market` | 3 | 3 | 0 | 0 | 8 |
| `nature` | 55 | 51 | 4 | 0 | 4.44 |

## Sanity Scenario QA

- Generated scenarios: 30
- Absurd/issue scenarios: 2
- Full file: `backend/src/main/resources/data/ai_handoff/semantic_v1/semantic_sanity_scenarios_v1.csv`

Issues:

- `vung_tau` / `AM_THUC`: top5_missing_expected_semantic_family (observed: local)
- `ha_noi` / `AM_THUC`: top5_missing_expected_semantic_family (observed: local)

## NEED_REVIEW Places

- `da_lat:happy_hill` - Happy Hill: Catalog category is food but canonical name indicates a hill/check-in attraction.
- `da_lat:nha_tho_con_ga` - Nhà Thờ Con Gà: Catalog category is lake but canonical name is a church.
- `da_lat:puppy_farm` - Puppy Farm: Catalog category is food but canonical name indicates a farm attraction.
- `da_nang_hue_hoi_an:pho_co_hoi_an` - Phố Cổ Hội An: Catalog category is lake but canonical name is an old town.
- `ha_noi:lang_chu_tich_ho_chi_minh` - Lăng Chủ Tịch Hồ Chí Minh: Catalog category is lake but canonical name is a mausoleum.
- `ha_noi:nha_tho_da_sapa` - Nhà Thờ Đá Sapa: Catalog category is lake but canonical name is a church.
- `ha_noi:pho_co_ha_noi` - Phố Cổ Hà Nội: Catalog category is lake but canonical name is an old quarter.
- `vung_tau:bien_ho_coc` - Biển Hồ Cốc: Catalog category is lake but canonical name indicates a beach.
- `vung_tau:bien_ho_tram` - Biển Hồ Tràm: Catalog category is lake but canonical name indicates a beach.

## PARTIAL Places

- `da_lat:bao_tang_madame_de` - Bảo Tàng Madame De: category-derived baseline exists but enrichment evidence remains limited
- `da_lat:chua_linh_an` - Chùa Linh Ẩn: category-derived baseline exists but enrichment evidence remains limited
- `da_lat:chua_linh_phuoc` - Chùa Linh Phước: category-derived baseline exists but enrichment evidence remains limited
- `da_lat:chua_thien_vuong_co_sat` - Chùa Thiên Vương Cổ Sát: category-derived baseline exists but enrichment evidence remains limited
- `da_lat:crazy_house` - Crazy House: category-derived baseline exists but enrichment evidence remains limited
- `da_lat:dai_bao_thap_kinh_luan` - Đại Bảo Tháp Kinh Luân: category-derived baseline exists but enrichment evidence remains limited
- `da_lat:dapa_hill` - Dapa Hill: category-derived baseline exists but enrichment evidence remains limited
- `da_lat:dinh_bao_dai` - Dinh Bảo Đại: category-derived baseline exists but enrichment evidence remains limited
- `da_lat:dinh_i` - Dinh I: category-derived baseline exists but enrichment evidence remains limited
- `da_lat:duong_ham_dat_set` - Đường Hầm Đất Sét: category-derived baseline exists but enrichment evidence remains limited
- `da_lat:fresh_garden` - Fresh Garden: category-derived baseline exists but enrichment evidence remains limited
- `da_lat:gallery_la_chocotea` - Gallery La Chocotea: category-derived baseline exists but enrichment evidence remains limited
- `da_lat:hoa_son_dien_trang` - Hoa Sơn Điền Trang: category-derived baseline exists but enrichment evidence remains limited
- `da_lat:kombi_land` - Kombi Land: category-derived baseline exists but enrichment evidence remains limited
- `da_lat:lac_hu_co_tran` - Lạc Hư Cổ Trấn: category-derived baseline exists but enrichment evidence remains limited
- `da_lat:mongo_land` - Mongo Land: category-derived baseline exists but enrichment evidence remains limited
- `da_lat:nac_thang_thien_duong` - Nấc Thang Thiên Đường: category-derived baseline exists but enrichment evidence remains limited
- `da_lat:nha_tho_domain_de_marie` - Nhà Thờ Domain De Marie: category-derived baseline exists but enrichment evidence remains limited
- `da_lat:que_garden` - Que Garden: category-derived baseline exists but enrichment evidence remains limited
- `da_lat:royal_garden` - Royal Garden: category-derived baseline exists but enrichment evidence remains limited
- `da_lat:samten_hills` - Samten Hills: category-derived baseline exists but enrichment evidence remains limited
- `da_lat:thi_tran_iyashi` - Thị Trấn Iyashi: category-derived baseline exists but enrichment evidence remains limited
- `da_lat:thien_vien_truc_lam` - Thiền Viện Trúc Lâm: category-derived baseline exists but enrichment evidence remains limited
- `da_lat:thien_vien_van_hanh` - Thiền Viện Vạn Hạnh: category-derived baseline exists but enrichment evidence remains limited
- `da_lat:trai_mat` - Trại Mát: category-derived baseline exists but enrichment evidence remains limited
- `da_lat:xuong_to_lua` - Xưởng Tơ Lụa: category-derived baseline exists but enrichment evidence remains limited
- `da_nang_hue_hoi_an:chua_linh_ung_son_tra` - Chùa Linh Ứng Sơn Trà: category-derived baseline exists but enrichment evidence remains limited
- `da_nang_hue_hoi_an:chua_thien_mu` - Chùa Thiên Mụ: category-derived baseline exists but enrichment evidence remains limited
- `da_nang_hue_hoi_an:dai_noi_hue` - Đại Nội Huế: category-derived baseline exists but enrichment evidence remains limited
- `da_nang_hue_hoi_an:ngu_hanh_son` - Ngũ Hành Sơn: category-derived baseline exists but enrichment evidence remains limited
- `da_nang_hue_hoi_an:thanh_dia_la_vang` - Thánh Địa La Vang: category-derived baseline exists but enrichment evidence remains limited
- `da_nang_hue_hoi_an:thanh_dia_my_son` - Thánh Địa Mỹ Sơn: category-derived baseline exists but enrichment evidence remains limited
- `ha_noi:bao_tang_dan_toc_hoc` - Bảo Tàng Dân Tộc Học: category-derived baseline exists but enrichment evidence remains limited
- `ha_noi:chua_huong` - Chùa Hương: category-derived baseline exists but enrichment evidence remains limited
- `ha_noi:chua_mot_cot` - Chùa Một Cột: category-derived baseline exists but enrichment evidence remains limited
- `ha_noi:chua_tran_quoc` - Chùa Trấn Quốc: category-derived baseline exists but enrichment evidence remains limited
- `ha_noi:den_ngoc_son` - Đền Ngọc Sơn: category-derived baseline exists but enrichment evidence remains limited
- `ha_noi:hoa_lu` - Hoa Lư: category-derived baseline exists but enrichment evidence remains limited
- `ha_noi:mai_chau` - Mai Châu: category-derived baseline exists but enrichment evidence remains limited
- `ha_noi:moana_sapa` - Moana Sapa: category-derived baseline exists but enrichment evidence remains limited
- `ha_noi:nha_hat_lon_ha_noi` - Nhà Hát Lớn Hà Nội: category-derived baseline exists but enrichment evidence remains limited
- `ha_noi:nha_tu_hoa_lo` - Nhà Tù Hỏa Lò: category-derived baseline exists but enrichment evidence remains limited
- `ha_noi:tam_coc` - Tam Cốc: category-derived baseline exists but enrichment evidence remains limited
- `ha_noi:trang_an` - Tràng An: category-derived baseline exists but enrichment evidence remains limited
- `ha_noi:tuan_chau` - Tuần Châu: category-derived baseline exists but enrichment evidence remains limited
- `ha_noi:van_mieu_quoc_tu_giam` - Văn Miếu Quốc Tử Giám: category-derived baseline exists but enrichment evidence remains limited
- `ha_noi:vinh_ha_long` - Vịnh Hạ Long: category-derived baseline exists but enrichment evidence remains limited
- `ha_noi:yen_tu` - Yên Tử: category-derived baseline exists but enrichment evidence remains limited
- `phan_thiet:bao_tang_ngoc_trai` - Bảo Tàng Ngọc Trai: category-derived baseline exists but enrichment evidence remains limited
- `phan_thiet:dinh_van_thuy_tu` - Dinh Vạn Thủy Tú: category-derived baseline exists but enrichment evidence remains limited
- `phan_thiet:lau_dai_ruou_vang` - Lâu Đài Rượu Vang: category-derived baseline exists but enrichment evidence remains limited
- `phan_thiet:lau_ong_hoang` - Lầu Ông Hoàng: category-derived baseline exists but enrichment evidence remains limited
- `phan_thiet:thap_cham_poshanu` - Tháp Chàm Poshanu: category-derived baseline exists but enrichment evidence remains limited
- `phan_thiet:truong_duc_thanh` - Trường Dục Thanh: category-derived baseline exists but enrichment evidence remains limited
- `vung_tau:bach_dinh` - Bạch Dinh: category-derived baseline exists but enrichment evidence remains limited
- `vung_tau:dai_tong_lam` - Đại Tòng Lâm: category-derived baseline exists but enrichment evidence remains limited
- `vung_tau:dinh_co` - Dinh Cô: category-derived baseline exists but enrichment evidence remains limited
- `vung_tau:khu_gieng_troi_binh_chau` - Khu Giếng Trời Bình Châu: category-derived baseline exists but enrichment evidence remains limited
- `vung_tau:marina_vung_tau` - Marina Vũng Tàu: category-derived baseline exists but enrichment evidence remains limited
- `vung_tau:nha_lon_long_son` - Nhà Lớn Long Sơn: category-derived baseline exists but enrichment evidence remains limited
- `vung_tau:thap_tam_thang` - Tháp Tam Thắng: category-derived baseline exists but enrichment evidence remains limited
- `vung_tau:thap_vong_thien` - Tháp Vọng Thiên: category-derived baseline exists but enrichment evidence remains limited
- `vung_tau:thich_ca_phat_dai` - Thích Ca Phật Đài: category-derived baseline exists but enrichment evidence remains limited
- `vung_tau:thien_vien_thuong_chieu` - Thiền Viện Thường Chiếu: category-derived baseline exists but enrichment evidence remains limited
- `vung_tau:thien_vien_truc_lam_chan_nguyen` - Thiền Viện Trúc Lâm Chân Nguyên: category-derived baseline exists but enrichment evidence remains limited

## Sanity Ranking Samples

### NGHI_DUONG

- 1. `vung_tau:suoi_nuoc_nong_binh_chau` - Suối Nước Nóng Bình Châu (2.64)
- 2. `da_lat:ho_xuan_huong` - Hồ Xuân Hương (2.26)
- 3. `vung_tau:ho_suoi_mo_binh_chau` - Hồ Suối Mơ Bình Châu (2.2)
- 4. `vung_tau:ho_may` - Hồ Mây (2.2)
- 5. `vung_tau:bien_ho_tram` - Biển Hồ Tràm (2.2)
### THIEN_NHIEN

- 1. `vung_tau:doi_cuu_suoi_nghe` - Đồi Cừu Suối Nghệ (2.76)
- 2. `vung_tau:ho_suoi_mo_binh_chau` - Hồ Suối Mơ Bình Châu (2.72)
- 3. `phan_thiet:suoi_tien` - Suối Tiên (2.72)
- 4. `vung_tau:suoi_nuoc_nong_binh_chau` - Suối Nước Nóng Bình Châu (2.12)
- 5. `vung_tau:suoi_da` - Suối Đá (2.12)
### VAN_HOA

- 1. `phan_thiet:bao_tang_ngoc_trai` - Bảo Tàng Ngọc Trai (3.2)
- 2. `ha_noi:bao_tang_dan_toc_hoc` - Bảo Tàng Dân Tộc Học (3.2)
- 3. `da_lat:bao_tang_madame_de` - Bảo Tàng Madame De (3.2)
- 4. `vung_tau:niet_ban_tinh_xa` - Niết Bàn Tịnh Xá (2.76)
- 5. `vung_tau:lang_ca_ong` - Lăng Cá Ông (2.76)
### AM_THUC

- 1. `da_lat:lang_art_cafe` - Lặng Art Café (2.48)
- 2. `da_lat:cafe_mien_du_muc` - Cafe Miền Du Mục (2.24)
- 3. `da_lat:cafe_me_linh` - Cafe Mê Linh (2.24)
- 4. `phan_thiet:cho_phan_thiet` - Chợ Phan Thiết (1.64)
- 5. `da_nang_hue_hoi_an:cho_dong_ba` - Chợ Đông Ba (1.64)
### CHECKIN_HOT

- 1. `da_lat:vuon_hoa_thanh_pho` - Vườn Hoa Thành Phố (2.72)
- 2. `da_lat:vuon_dia_dang` - Vườn Địa Đàng (2.72)
- 3. `da_lat:vuon_dau_da_lat` - Vườn Dâu Đà Lạt (2.72)
- 4. `da_lat:vuon_chau_au` - Vườn Châu Âu (2.72)
- 5. `da_lat:lang_hoa_van_thanh` - Làng Hoa Vạn Thành (2.72)
### KET_BAN

- 1. `da_lat:quang_truong_lam_vien` - Quảng Trường Lâm Viên (2.12)
- 2. `vung_tau:cong_vien_rung_minera` - Công Viên Rừng Minera (1.44)
- 3. `phan_thiet:cong_vien_bikini_beach` - Công Viên Bikini Beach (1.44)
- 4. `vung_tau:kdl_ngoc_xuong` - KDL Ngọc Xương (1.08)
- 5. `vung_tau:kdl_bien_dong` - KDL Biển Đông (1.08)

## Notes

- `semantic_status` and `runtime_eligible` live in the AI artifact, not PostgreSQL schema.
- PostgreSQL `place_tag_links` is synced only for runtime places already present in `places`.
- The 42 coordinate-unresolved canonical places remain in the AI artifact with `runtime_eligible=false`.
- Existing taxonomy and interest mappings are frozen for this release.
