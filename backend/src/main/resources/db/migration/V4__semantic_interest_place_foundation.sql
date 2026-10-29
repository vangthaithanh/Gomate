CREATE TABLE IF NOT EXISTS interest_groups (
 id BIGSERIAL PRIMARY KEY,
 code VARCHAR(50) NOT NULL UNIQUE,
 name VARCHAR(100) NOT NULL,
 description TEXT,
 sort_order INT NOT NULL,
 active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS interest_options (
 id BIGSERIAL PRIMARY KEY,
 group_id BIGINT NOT NULL REFERENCES interest_groups(id),
 code VARCHAR(60) NOT NULL UNIQUE,
 label VARCHAR(120) NOT NULL,
 description TEXT,
 sort_order INT NOT NULL,
 active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS user_interests (
 user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 interest_option_id BIGINT NOT NULL REFERENCES interest_options(id),
 preference_weight NUMERIC(4,3) NOT NULL DEFAULT 1.000 CHECK (preference_weight IN (0.300,0.600,0.800,1.000)),
 selected_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
 PRIMARY KEY (user_id,interest_option_id)
);

CREATE TABLE IF NOT EXISTS place_tags (
 id BIGSERIAL PRIMARY KEY,
 code VARCHAR(60) NOT NULL UNIQUE,
 label VARCHAR(100) NOT NULL,
 active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS place_tag_links (
 place_id BIGINT NOT NULL REFERENCES places(id) ON DELETE CASCADE,
 tag_id BIGINT NOT NULL REFERENCES place_tags(id),
 weight NUMERIC(4,3) NOT NULL DEFAULT 1.000 CHECK (weight IN (0.300,0.600,0.800,1.000)),
 PRIMARY KEY (place_id,tag_id)
);

CREATE TABLE IF NOT EXISTS interest_tag_mappings (
 interest_option_id BIGINT NOT NULL REFERENCES interest_options(id) ON DELETE CASCADE,
 tag_id BIGINT NOT NULL REFERENCES place_tags(id),
 weight NUMERIC(4,3) NOT NULL DEFAULT 1.000 CHECK (weight IN (0.300,0.600,0.800,1.000)),
 PRIMARY KEY (interest_option_id,tag_id)
);

CREATE INDEX IF NOT EXISTS ix_interest_options_group ON interest_options(group_id,sort_order,id);
CREATE INDEX IF NOT EXISTS ix_user_interests_option ON user_interests(interest_option_id);
CREATE INDEX IF NOT EXISTS ix_place_tag_links_tag ON place_tag_links(tag_id);
CREATE INDEX IF NOT EXISTS ix_interest_tag_mappings_tag ON interest_tag_mappings(tag_id);

INSERT INTO interest_groups(code,name,description,sort_order,active)
SELECT 'TRAVEL_INTENT','Travel intent','Semantic travel intent from survey screen 1.',1,TRUE
WHERE NOT EXISTS (SELECT 1 FROM interest_groups WHERE code='TRAVEL_INTENT');
INSERT INTO interest_groups(code,name,description,sort_order,active)
SELECT 'ENVIRONMENT_PREFERENCE','Environment preference','Semantic environment preference from survey screen 2.',2,TRUE
WHERE NOT EXISTS (SELECT 1 FROM interest_groups WHERE code='ENVIRONMENT_PREFERENCE');
INSERT INTO interest_groups(code,name,description,sort_order,active)
SELECT 'CONTEXT_STRATEGY','Context strategy','Runtime recommendation context from survey screen 3; not stored as long-term semantic profile.',3,TRUE
WHERE NOT EXISTS (SELECT 1 FROM interest_groups WHERE code='CONTEXT_STRATEGY');

INSERT INTO interest_options(group_id,code,label,description,sort_order,active)
SELECT g.id,'KET_BAN','Kết bạn','User wants social/group-friendly travel experiences.',1,TRUE FROM interest_groups g
WHERE g.code='TRAVEL_INTENT' AND NOT EXISTS (SELECT 1 FROM interest_options WHERE code='KET_BAN');
INSERT INTO interest_options(group_id,code,label,description,sort_order,active)
SELECT g.id,'NGHI_DUONG','Nghỉ dưỡng','User wants relaxing, quiet, resort-like experiences.',2,TRUE FROM interest_groups g
WHERE g.code='TRAVEL_INTENT' AND NOT EXISTS (SELECT 1 FROM interest_options WHERE code='NGHI_DUONG');
INSERT INTO interest_options(group_id,code,label,description,sort_order,active)
SELECT g.id,'CHECKIN_HOT','Check-in hot','User wants photogenic, iconic, trendy places.',3,TRUE FROM interest_groups g
WHERE g.code='TRAVEL_INTENT' AND NOT EXISTS (SELECT 1 FROM interest_options WHERE code='CHECKIN_HOT');
INSERT INTO interest_options(group_id,code,label,description,sort_order,active)
SELECT g.id,'THIEN_NHIEN','Thiên nhiên','User wants nature, lake, mountain, waterfall or forest experiences.',4,TRUE FROM interest_groups g
WHERE g.code='TRAVEL_INTENT' AND NOT EXISTS (SELECT 1 FROM interest_options WHERE code='THIEN_NHIEN');
INSERT INTO interest_options(group_id,code,label,description,sort_order,active)
SELECT g.id,'VAN_HOA','Văn hóa lịch sử','User wants cultural, historical, heritage and museum places.',5,TRUE FROM interest_groups g
WHERE g.code='TRAVEL_INTENT' AND NOT EXISTS (SELECT 1 FROM interest_options WHERE code='VAN_HOA');
INSERT INTO interest_options(group_id,code,label,description,sort_order,active)
SELECT g.id,'AM_THUC','Ẩm thực','User wants food, local food, market and cafe experiences.',6,TRUE FROM interest_groups g
WHERE g.code='TRAVEL_INTENT' AND NOT EXISTS (SELECT 1 FROM interest_options WHERE code='AM_THUC');
INSERT INTO interest_options(group_id,code,label,description,sort_order,active)
SELECT g.id,'MUC_DICH_KHAC','Mục đích khác','Other travel intent; kept for survey compatibility, no semantic tag mapping in v1.',7,TRUE FROM interest_groups g
WHERE g.code='TRAVEL_INTENT' AND NOT EXISTS (SELECT 1 FROM interest_options WHERE code='MUC_DICH_KHAC');

INSERT INTO interest_options(group_id,code,label,description,sort_order,active)
SELECT g.id,'BIEN_NUI','Biển núi','User prefers sea, mountain and scenic nature environments.',1,TRUE FROM interest_groups g
WHERE g.code='ENVIRONMENT_PREFERENCE' AND NOT EXISTS (SELECT 1 FROM interest_options WHERE code='BIEN_NUI');
INSERT INTO interest_options(group_id,code,label,description,sort_order,active)
SELECT g.id,'TRUNG_TAM','Trung tâm','User prefers city center and urban environments.',2,TRUE FROM interest_groups g
WHERE g.code='ENVIRONMENT_PREFERENCE' AND NOT EXISTS (SELECT 1 FROM interest_options WHERE code='TRUNG_TAM');
INSERT INTO interest_options(group_id,code,label,description,sort_order,active)
SELECT g.id,'DIA_DANH_NOI_TIENG','Địa danh nổi tiếng','User prefers famous landmarks and iconic places.',3,TRUE FROM interest_groups g
WHERE g.code='ENVIRONMENT_PREFERENCE' AND NOT EXISTS (SELECT 1 FROM interest_options WHERE code='DIA_DANH_NOI_TIENG');
INSERT INTO interest_options(group_id,code,label,description,sort_order,active)
SELECT g.id,'LANG_NGHE_DI_TICH','Làng nghề di tích','User prefers heritage, cultural and historical places.',4,TRUE FROM interest_groups g
WHERE g.code='ENVIRONMENT_PREFERENCE' AND NOT EXISTS (SELECT 1 FROM interest_options WHERE code='LANG_NGHE_DI_TICH');
INSERT INTO interest_options(group_id,code,label,description,sort_order,active)
SELECT g.id,'NGOAI_O_DONG_QUE','Ngoại ô đồng quê','User prefers countryside, local and nature-oriented environments.',5,TRUE FROM interest_groups g
WHERE g.code='ENVIRONMENT_PREFERENCE' AND NOT EXISTS (SELECT 1 FROM interest_options WHERE code='NGOAI_O_DONG_QUE');
INSERT INTO interest_options(group_id,code,label,description,sort_order,active)
SELECT g.id,'LOAI_KHAC','Loại khác','Other environment preference; kept for survey compatibility, no semantic tag mapping in v1.',6,TRUE FROM interest_groups g
WHERE g.code='ENVIRONMENT_PREFERENCE' AND NOT EXISTS (SELECT 1 FROM interest_options WHERE code='LOAI_KHAC');

INSERT INTO interest_options(group_id,code,label,description,sort_order,active)
SELECT g.id,'GAN_TOI','Gần tôi','Context strategy owned by backend runtime distance/GPS.',1,TRUE FROM interest_groups g
WHERE g.code='CONTEXT_STRATEGY' AND NOT EXISTS (SELECT 1 FROM interest_options WHERE code='GAN_TOI');
INSERT INTO interest_options(group_id,code,label,description,sort_order,active)
SELECT g.id,'LOCAL','Địa điểm local','Shared context strategy using local tags plus backend re-ranking.',2,TRUE FROM interest_groups g
WHERE g.code='CONTEXT_STRATEGY' AND NOT EXISTS (SELECT 1 FROM interest_options WHERE code='LOCAL');
INSERT INTO interest_options(group_id,code,label,description,sort_order,active)
SELECT g.id,'DANG_HOT','Đang hot','Context strategy owned by popularity/trend signal.',3,TRUE FROM interest_groups g
WHERE g.code='CONTEXT_STRATEGY' AND NOT EXISTS (SELECT 1 FROM interest_options WHERE code='DANG_HOT');
INSERT INTO interest_options(group_id,code,label,description,sort_order,active)
SELECT g.id,'DI_TRONG_NGAY','Đi trong ngày','Context strategy owned by route duration, distance and available time.',4,TRUE FROM interest_groups g
WHERE g.code='CONTEXT_STRATEGY' AND NOT EXISTS (SELECT 1 FROM interest_options WHERE code='DI_TRONG_NGAY');
INSERT INTO interest_options(group_id,code,label,description,sort_order,active)
SELECT g.id,'CO_REVIEW','Có review','Context strategy owned by review count and rating signals.',5,TRUE FROM interest_groups g
WHERE g.code='CONTEXT_STRATEGY' AND NOT EXISTS (SELECT 1 FROM interest_options WHERE code='CO_REVIEW');
INSERT INTO interest_options(group_id,code,label,description,sort_order,active)
SELECT g.id,'UU_TIEN_KHAC','Ưu tiên khác','Other context strategy; kept for survey compatibility.',6,TRUE FROM interest_groups g
WHERE g.code='CONTEXT_STRATEGY' AND NOT EXISTS (SELECT 1 FROM interest_options WHERE code='UU_TIEN_KHAC');

INSERT INTO place_tags(code,label,active)
SELECT 'relaxing','Relaxing',TRUE WHERE NOT EXISTS (SELECT 1 FROM place_tags WHERE code='relaxing');
INSERT INTO place_tags(code,label,active)
SELECT 'quiet','Quiet',TRUE WHERE NOT EXISTS (SELECT 1 FROM place_tags WHERE code='quiet');
INSERT INTO place_tags(code,label,active)
SELECT 'scenic','Scenic',TRUE WHERE NOT EXISTS (SELECT 1 FROM place_tags WHERE code='scenic');
INSERT INTO place_tags(code,label,active)
SELECT 'nature','Nature',TRUE WHERE NOT EXISTS (SELECT 1 FROM place_tags WHERE code='nature');
INSERT INTO place_tags(code,label,active)
SELECT 'lake','Lake',TRUE WHERE NOT EXISTS (SELECT 1 FROM place_tags WHERE code='lake');
INSERT INTO place_tags(code,label,active)
SELECT 'beach','Beach',TRUE WHERE NOT EXISTS (SELECT 1 FROM place_tags WHERE code='beach');
INSERT INTO place_tags(code,label,active)
SELECT 'mountain','Mountain',TRUE WHERE NOT EXISTS (SELECT 1 FROM place_tags WHERE code='mountain');
INSERT INTO place_tags(code,label,active)
SELECT 'waterfall','Waterfall',TRUE WHERE NOT EXISTS (SELECT 1 FROM place_tags WHERE code='waterfall');
INSERT INTO place_tags(code,label,active)
SELECT 'forest','Forest',TRUE WHERE NOT EXISTS (SELECT 1 FROM place_tags WHERE code='forest');
INSERT INTO place_tags(code,label,active)
SELECT 'social','Social',TRUE WHERE NOT EXISTS (SELECT 1 FROM place_tags WHERE code='social');
INSERT INTO place_tags(code,label,active)
SELECT 'group_friendly','Group friendly',TRUE WHERE NOT EXISTS (SELECT 1 FROM place_tags WHERE code='group_friendly');
INSERT INTO place_tags(code,label,active)
SELECT 'crowded','Crowded',TRUE WHERE NOT EXISTS (SELECT 1 FROM place_tags WHERE code='crowded');
INSERT INTO place_tags(code,label,active)
SELECT 'event_place','Event place',TRUE WHERE NOT EXISTS (SELECT 1 FROM place_tags WHERE code='event_place');
INSERT INTO place_tags(code,label,active)
SELECT 'cafe_meeting','Cafe meeting',TRUE WHERE NOT EXISTS (SELECT 1 FROM place_tags WHERE code='cafe_meeting');
INSERT INTO place_tags(code,label,active)
SELECT 'walking_area','Walking area',TRUE WHERE NOT EXISTS (SELECT 1 FROM place_tags WHERE code='walking_area');
INSERT INTO place_tags(code,label,active)
SELECT 'night_market','Night market',TRUE WHERE NOT EXISTS (SELECT 1 FROM place_tags WHERE code='night_market');
INSERT INTO place_tags(code,label,active)
SELECT 'photo_spot','Photo spot',TRUE WHERE NOT EXISTS (SELECT 1 FROM place_tags WHERE code='photo_spot');
INSERT INTO place_tags(code,label,active)
SELECT 'landmark','Landmark',TRUE WHERE NOT EXISTS (SELECT 1 FROM place_tags WHERE code='landmark');
INSERT INTO place_tags(code,label,active)
SELECT 'iconic','Iconic',TRUE WHERE NOT EXISTS (SELECT 1 FROM place_tags WHERE code='iconic');
INSERT INTO place_tags(code,label,active)
SELECT 'trendy','Trendy',TRUE WHERE NOT EXISTS (SELECT 1 FROM place_tags WHERE code='trendy');
INSERT INTO place_tags(code,label,active)
SELECT 'local','Local',TRUE WHERE NOT EXISTS (SELECT 1 FROM place_tags WHERE code='local');
INSERT INTO place_tags(code,label,active)
SELECT 'local_food','Local food',TRUE WHERE NOT EXISTS (SELECT 1 FROM place_tags WHERE code='local_food');
INSERT INTO place_tags(code,label,active)
SELECT 'local_market','Local market',TRUE WHERE NOT EXISTS (SELECT 1 FROM place_tags WHERE code='local_market');
INSERT INTO place_tags(code,label,active)
SELECT 'local_culture','Local culture',TRUE WHERE NOT EXISTS (SELECT 1 FROM place_tags WHERE code='local_culture');
INSERT INTO place_tags(code,label,active)
SELECT 'cultural','Cultural',TRUE WHERE NOT EXISTS (SELECT 1 FROM place_tags WHERE code='cultural');
INSERT INTO place_tags(code,label,active)
SELECT 'historical','Historical',TRUE WHERE NOT EXISTS (SELECT 1 FROM place_tags WHERE code='historical');
INSERT INTO place_tags(code,label,active)
SELECT 'heritage','Heritage',TRUE WHERE NOT EXISTS (SELECT 1 FROM place_tags WHERE code='heritage');
INSERT INTO place_tags(code,label,active)
SELECT 'museum','Museum',TRUE WHERE NOT EXISTS (SELECT 1 FROM place_tags WHERE code='museum');
INSERT INTO place_tags(code,label,active)
SELECT 'food','Food',TRUE WHERE NOT EXISTS (SELECT 1 FROM place_tags WHERE code='food');
INSERT INTO place_tags(code,label,active)
SELECT 'cafe','Cafe',TRUE WHERE NOT EXISTS (SELECT 1 FROM place_tags WHERE code='cafe');
INSERT INTO place_tags(code,label,active)
SELECT 'market','Market',TRUE WHERE NOT EXISTS (SELECT 1 FROM place_tags WHERE code='market');
INSERT INTO place_tags(code,label,active)
SELECT 'night_activity','Night activity',TRUE WHERE NOT EXISTS (SELECT 1 FROM place_tags WHERE code='night_activity');
INSERT INTO place_tags(code,label,active)
SELECT 'resort_spa','Resort and spa',TRUE WHERE NOT EXISTS (SELECT 1 FROM place_tags WHERE code='resort_spa');
INSERT INTO place_tags(code,label,active)
SELECT 'city_center','City center',TRUE WHERE NOT EXISTS (SELECT 1 FROM place_tags WHERE code='city_center');
INSERT INTO place_tags(code,label,active)
SELECT 'urban','Urban',TRUE WHERE NOT EXISTS (SELECT 1 FROM place_tags WHERE code='urban');
INSERT INTO place_tags(code,label,active)
SELECT 'countryside','Countryside',TRUE WHERE NOT EXISTS (SELECT 1 FROM place_tags WHERE code='countryside');

INSERT INTO interest_tag_mappings(interest_option_id,tag_id,weight)
SELECT io.id,pt.id,CAST(1.000 AS NUMERIC(4,3)) FROM interest_options io,place_tags pt
WHERE io.code='NGHI_DUONG' AND pt.code='relaxing' AND NOT EXISTS (SELECT 1 FROM interest_tag_mappings m WHERE m.interest_option_id=io.id AND m.tag_id=pt.id);
INSERT INTO interest_tag_mappings(interest_option_id,tag_id,weight)
SELECT io.id,pt.id,CAST(0.800 AS NUMERIC(4,3)) FROM interest_options io,place_tags pt
WHERE io.code='NGHI_DUONG' AND pt.code IN ('quiet','scenic') AND NOT EXISTS (SELECT 1 FROM interest_tag_mappings m WHERE m.interest_option_id=io.id AND m.tag_id=pt.id);
INSERT INTO interest_tag_mappings(interest_option_id,tag_id,weight)
SELECT io.id,pt.id,CAST(1.000 AS NUMERIC(4,3)) FROM interest_options io,place_tags pt
WHERE io.code='NGHI_DUONG' AND pt.code='resort_spa' AND NOT EXISTS (SELECT 1 FROM interest_tag_mappings m WHERE m.interest_option_id=io.id AND m.tag_id=pt.id);
INSERT INTO interest_tag_mappings(interest_option_id,tag_id,weight)
SELECT io.id,pt.id,CAST(0.600 AS NUMERIC(4,3)) FROM interest_options io,place_tags pt
WHERE io.code='NGHI_DUONG' AND pt.code='nature' AND NOT EXISTS (SELECT 1 FROM interest_tag_mappings m WHERE m.interest_option_id=io.id AND m.tag_id=pt.id);
INSERT INTO interest_tag_mappings(interest_option_id,tag_id,weight)
SELECT io.id,pt.id,CAST(0.300 AS NUMERIC(4,3)) FROM interest_options io,place_tags pt
WHERE io.code='NGHI_DUONG' AND pt.code IN ('lake','walking_area') AND NOT EXISTS (SELECT 1 FROM interest_tag_mappings m WHERE m.interest_option_id=io.id AND m.tag_id=pt.id);

INSERT INTO interest_tag_mappings(interest_option_id,tag_id,weight)
SELECT io.id,pt.id,CAST(1.000 AS NUMERIC(4,3)) FROM interest_options io,place_tags pt
WHERE io.code='KET_BAN' AND pt.code='social' AND NOT EXISTS (SELECT 1 FROM interest_tag_mappings m WHERE m.interest_option_id=io.id AND m.tag_id=pt.id);
INSERT INTO interest_tag_mappings(interest_option_id,tag_id,weight)
SELECT io.id,pt.id,CAST(0.800 AS NUMERIC(4,3)) FROM interest_options io,place_tags pt
WHERE io.code='KET_BAN' AND pt.code IN ('group_friendly','cafe_meeting','event_place') AND NOT EXISTS (SELECT 1 FROM interest_tag_mappings m WHERE m.interest_option_id=io.id AND m.tag_id=pt.id);
INSERT INTO interest_tag_mappings(interest_option_id,tag_id,weight)
SELECT io.id,pt.id,CAST(0.600 AS NUMERIC(4,3)) FROM interest_options io,place_tags pt
WHERE io.code='KET_BAN' AND pt.code IN ('crowded','walking_area') AND NOT EXISTS (SELECT 1 FROM interest_tag_mappings m WHERE m.interest_option_id=io.id AND m.tag_id=pt.id);
INSERT INTO interest_tag_mappings(interest_option_id,tag_id,weight)
SELECT io.id,pt.id,CAST(0.300 AS NUMERIC(4,3)) FROM interest_options io,place_tags pt
WHERE io.code='KET_BAN' AND pt.code='night_market' AND NOT EXISTS (SELECT 1 FROM interest_tag_mappings m WHERE m.interest_option_id=io.id AND m.tag_id=pt.id);

INSERT INTO interest_tag_mappings(interest_option_id,tag_id,weight)
SELECT io.id,pt.id,CAST(1.000 AS NUMERIC(4,3)) FROM interest_options io,place_tags pt
WHERE io.code='CHECKIN_HOT' AND pt.code='photo_spot' AND NOT EXISTS (SELECT 1 FROM interest_tag_mappings m WHERE m.interest_option_id=io.id AND m.tag_id=pt.id);
INSERT INTO interest_tag_mappings(interest_option_id,tag_id,weight)
SELECT io.id,pt.id,CAST(0.800 AS NUMERIC(4,3)) FROM interest_options io,place_tags pt
WHERE io.code='CHECKIN_HOT' AND pt.code IN ('scenic','landmark','iconic') AND NOT EXISTS (SELECT 1 FROM interest_tag_mappings m WHERE m.interest_option_id=io.id AND m.tag_id=pt.id);
INSERT INTO interest_tag_mappings(interest_option_id,tag_id,weight)
SELECT io.id,pt.id,CAST(0.600 AS NUMERIC(4,3)) FROM interest_options io,place_tags pt
WHERE io.code='CHECKIN_HOT' AND pt.code='trendy' AND NOT EXISTS (SELECT 1 FROM interest_tag_mappings m WHERE m.interest_option_id=io.id AND m.tag_id=pt.id);

INSERT INTO interest_tag_mappings(interest_option_id,tag_id,weight)
SELECT io.id,pt.id,CAST(1.000 AS NUMERIC(4,3)) FROM interest_options io,place_tags pt
WHERE io.code='THIEN_NHIEN' AND pt.code='nature' AND NOT EXISTS (SELECT 1 FROM interest_tag_mappings m WHERE m.interest_option_id=io.id AND m.tag_id=pt.id);
INSERT INTO interest_tag_mappings(interest_option_id,tag_id,weight)
SELECT io.id,pt.id,CAST(0.800 AS NUMERIC(4,3)) FROM interest_options io,place_tags pt
WHERE io.code='THIEN_NHIEN' AND pt.code IN ('lake','mountain','waterfall','forest') AND NOT EXISTS (SELECT 1 FROM interest_tag_mappings m WHERE m.interest_option_id=io.id AND m.tag_id=pt.id);
INSERT INTO interest_tag_mappings(interest_option_id,tag_id,weight)
SELECT io.id,pt.id,CAST(0.600 AS NUMERIC(4,3)) FROM interest_options io,place_tags pt
WHERE io.code='THIEN_NHIEN' AND pt.code='scenic' AND NOT EXISTS (SELECT 1 FROM interest_tag_mappings m WHERE m.interest_option_id=io.id AND m.tag_id=pt.id);

INSERT INTO interest_tag_mappings(interest_option_id,tag_id,weight)
SELECT io.id,pt.id,CAST(1.000 AS NUMERIC(4,3)) FROM interest_options io,place_tags pt
WHERE io.code='VAN_HOA' AND pt.code IN ('cultural','historical') AND NOT EXISTS (SELECT 1 FROM interest_tag_mappings m WHERE m.interest_option_id=io.id AND m.tag_id=pt.id);
INSERT INTO interest_tag_mappings(interest_option_id,tag_id,weight)
SELECT io.id,pt.id,CAST(0.800 AS NUMERIC(4,3)) FROM interest_options io,place_tags pt
WHERE io.code='VAN_HOA' AND pt.code IN ('heritage','museum') AND NOT EXISTS (SELECT 1 FROM interest_tag_mappings m WHERE m.interest_option_id=io.id AND m.tag_id=pt.id);
INSERT INTO interest_tag_mappings(interest_option_id,tag_id,weight)
SELECT io.id,pt.id,CAST(0.600 AS NUMERIC(4,3)) FROM interest_options io,place_tags pt
WHERE io.code='VAN_HOA' AND pt.code='local_culture' AND NOT EXISTS (SELECT 1 FROM interest_tag_mappings m WHERE m.interest_option_id=io.id AND m.tag_id=pt.id);

INSERT INTO interest_tag_mappings(interest_option_id,tag_id,weight)
SELECT io.id,pt.id,CAST(1.000 AS NUMERIC(4,3)) FROM interest_options io,place_tags pt
WHERE io.code='AM_THUC' AND pt.code='food' AND NOT EXISTS (SELECT 1 FROM interest_tag_mappings m WHERE m.interest_option_id=io.id AND m.tag_id=pt.id);
INSERT INTO interest_tag_mappings(interest_option_id,tag_id,weight)
SELECT io.id,pt.id,CAST(0.800 AS NUMERIC(4,3)) FROM interest_options io,place_tags pt
WHERE io.code='AM_THUC' AND pt.code='local_food' AND NOT EXISTS (SELECT 1 FROM interest_tag_mappings m WHERE m.interest_option_id=io.id AND m.tag_id=pt.id);
INSERT INTO interest_tag_mappings(interest_option_id,tag_id,weight)
SELECT io.id,pt.id,CAST(0.600 AS NUMERIC(4,3)) FROM interest_options io,place_tags pt
WHERE io.code='AM_THUC' AND pt.code IN ('market','cafe') AND NOT EXISTS (SELECT 1 FROM interest_tag_mappings m WHERE m.interest_option_id=io.id AND m.tag_id=pt.id);
INSERT INTO interest_tag_mappings(interest_option_id,tag_id,weight)
SELECT io.id,pt.id,CAST(0.300 AS NUMERIC(4,3)) FROM interest_options io,place_tags pt
WHERE io.code='AM_THUC' AND pt.code='local' AND NOT EXISTS (SELECT 1 FROM interest_tag_mappings m WHERE m.interest_option_id=io.id AND m.tag_id=pt.id);

INSERT INTO interest_tag_mappings(interest_option_id,tag_id,weight)
SELECT io.id,pt.id,CAST(0.800 AS NUMERIC(4,3)) FROM interest_options io,place_tags pt
WHERE io.code='BIEN_NUI' AND pt.code IN ('nature','mountain','beach','scenic') AND NOT EXISTS (SELECT 1 FROM interest_tag_mappings m WHERE m.interest_option_id=io.id AND m.tag_id=pt.id);
INSERT INTO interest_tag_mappings(interest_option_id,tag_id,weight)
SELECT io.id,pt.id,CAST(0.800 AS NUMERIC(4,3)) FROM interest_options io,place_tags pt
WHERE io.code='TRUNG_TAM' AND pt.code IN ('city_center','urban','walking_area') AND NOT EXISTS (SELECT 1 FROM interest_tag_mappings m WHERE m.interest_option_id=io.id AND m.tag_id=pt.id);
INSERT INTO interest_tag_mappings(interest_option_id,tag_id,weight)
SELECT io.id,pt.id,CAST(0.800 AS NUMERIC(4,3)) FROM interest_options io,place_tags pt
WHERE io.code='DIA_DANH_NOI_TIENG' AND pt.code IN ('landmark','iconic','photo_spot') AND NOT EXISTS (SELECT 1 FROM interest_tag_mappings m WHERE m.interest_option_id=io.id AND m.tag_id=pt.id);
INSERT INTO interest_tag_mappings(interest_option_id,tag_id,weight)
SELECT io.id,pt.id,CAST(0.800 AS NUMERIC(4,3)) FROM interest_options io,place_tags pt
WHERE io.code='LANG_NGHE_DI_TICH' AND pt.code IN ('heritage','cultural','historical','local_culture') AND NOT EXISTS (SELECT 1 FROM interest_tag_mappings m WHERE m.interest_option_id=io.id AND m.tag_id=pt.id);
INSERT INTO interest_tag_mappings(interest_option_id,tag_id,weight)
SELECT io.id,pt.id,CAST(0.800 AS NUMERIC(4,3)) FROM interest_options io,place_tags pt
WHERE io.code='NGOAI_O_DONG_QUE' AND pt.code IN ('countryside','local','nature','scenic') AND NOT EXISTS (SELECT 1 FROM interest_tag_mappings m WHERE m.interest_option_id=io.id AND m.tag_id=pt.id);

INSERT INTO place_tag_links(place_id,tag_id,weight)
SELECT p.id,pt.id,CAST(1.000 AS NUMERIC(4,3)) FROM places p JOIN place_categories c ON c.id=p.category_id JOIN place_tags pt ON pt.code='lake'
WHERE c.code='lake' AND NOT EXISTS (SELECT 1 FROM place_tag_links l WHERE l.place_id=p.id AND l.tag_id=pt.id);
INSERT INTO place_tag_links(place_id,tag_id,weight)
SELECT p.id,pt.id,CAST(0.800 AS NUMERIC(4,3)) FROM places p JOIN place_categories c ON c.id=p.category_id JOIN place_tags pt ON pt.code='nature'
WHERE c.code='lake' AND NOT EXISTS (SELECT 1 FROM place_tag_links l WHERE l.place_id=p.id AND l.tag_id=pt.id);
INSERT INTO place_tag_links(place_id,tag_id,weight)
SELECT p.id,pt.id,CAST(0.600 AS NUMERIC(4,3)) FROM places p JOIN place_categories c ON c.id=p.category_id JOIN place_tags pt ON pt.code='scenic'
WHERE c.code='lake' AND NOT EXISTS (SELECT 1 FROM place_tag_links l WHERE l.place_id=p.id AND l.tag_id=pt.id);

INSERT INTO place_tag_links(place_id,tag_id,weight)
SELECT p.id,pt.id,CAST(1.000 AS NUMERIC(4,3)) FROM places p JOIN place_categories c ON c.id=p.category_id JOIN place_tags pt ON pt.code='heritage'
WHERE c.code='heritage' AND NOT EXISTS (SELECT 1 FROM place_tag_links l WHERE l.place_id=p.id AND l.tag_id=pt.id);
INSERT INTO place_tag_links(place_id,tag_id,weight)
SELECT p.id,pt.id,CAST(0.800 AS NUMERIC(4,3)) FROM places p JOIN place_categories c ON c.id=p.category_id JOIN place_tags pt ON pt.code IN ('cultural','historical')
WHERE c.code='heritage' AND NOT EXISTS (SELECT 1 FROM place_tag_links l WHERE l.place_id=p.id AND l.tag_id=pt.id);

INSERT INTO place_tag_links(place_id,tag_id,weight)
SELECT p.id,pt.id,CAST(1.000 AS NUMERIC(4,3)) FROM places p JOIN place_categories c ON c.id=p.category_id JOIN place_tags pt ON pt.code='market'
WHERE c.code='market' AND NOT EXISTS (SELECT 1 FROM place_tag_links l WHERE l.place_id=p.id AND l.tag_id=pt.id);
INSERT INTO place_tag_links(place_id,tag_id,weight)
SELECT p.id,pt.id,CAST(0.800 AS NUMERIC(4,3)) FROM places p JOIN place_categories c ON c.id=p.category_id JOIN place_tags pt ON pt.code='local'
WHERE c.code='market' AND NOT EXISTS (SELECT 1 FROM place_tag_links l WHERE l.place_id=p.id AND l.tag_id=pt.id);

INSERT INTO place_tag_links(place_id,tag_id,weight)
SELECT p.id,pt.id,CAST(1.000 AS NUMERIC(4,3)) FROM places p JOIN place_categories c ON c.id=p.category_id JOIN place_tags pt ON pt.code='food'
WHERE c.code='food' AND NOT EXISTS (SELECT 1 FROM place_tag_links l WHERE l.place_id=p.id AND l.tag_id=pt.id);
INSERT INTO place_tag_links(place_id,tag_id,weight)
SELECT p.id,pt.id,CAST(0.800 AS NUMERIC(4,3)) FROM places p JOIN place_categories c ON c.id=p.category_id JOIN place_tags pt ON pt.code='local_food'
WHERE c.code='food' AND NOT EXISTS (SELECT 1 FROM place_tag_links l WHERE l.place_id=p.id AND l.tag_id=pt.id);

INSERT INTO place_tag_links(place_id,tag_id,weight)
SELECT p.id,pt.id,CAST(1.000 AS NUMERIC(4,3)) FROM places p JOIN place_categories c ON c.id=p.category_id JOIN place_tags pt ON pt.code='landmark'
WHERE c.code='landmark' AND NOT EXISTS (SELECT 1 FROM place_tag_links l WHERE l.place_id=p.id AND l.tag_id=pt.id);
INSERT INTO place_tag_links(place_id,tag_id,weight)
SELECT p.id,pt.id,CAST(0.800 AS NUMERIC(4,3)) FROM places p JOIN place_categories c ON c.id=p.category_id JOIN place_tags pt ON pt.code='photo_spot'
WHERE c.code='landmark' AND NOT EXISTS (SELECT 1 FROM place_tag_links l WHERE l.place_id=p.id AND l.tag_id=pt.id);
INSERT INTO place_tag_links(place_id,tag_id,weight)
SELECT p.id,pt.id,CAST(0.600 AS NUMERIC(4,3)) FROM places p JOIN place_categories c ON c.id=p.category_id JOIN place_tags pt ON pt.code='iconic'
WHERE c.code='landmark' AND NOT EXISTS (SELECT 1 FROM place_tag_links l WHERE l.place_id=p.id AND l.tag_id=pt.id);

INSERT INTO place_tag_links(place_id,tag_id,weight)
SELECT p.id,pt.id,CAST(1.000 AS NUMERIC(4,3)) FROM places p JOIN place_categories c ON c.id=p.category_id JOIN place_tags pt ON pt.code='nature'
WHERE c.code='nature' AND NOT EXISTS (SELECT 1 FROM place_tag_links l WHERE l.place_id=p.id AND l.tag_id=pt.id);
INSERT INTO place_tag_links(place_id,tag_id,weight)
SELECT p.id,pt.id,CAST(0.600 AS NUMERIC(4,3)) FROM places p JOIN place_categories c ON c.id=p.category_id JOIN place_tags pt ON pt.code='scenic'
WHERE c.code='nature' AND NOT EXISTS (SELECT 1 FROM place_tag_links l WHERE l.place_id=p.id AND l.tag_id=pt.id);
