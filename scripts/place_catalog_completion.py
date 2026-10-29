import csv
import json
import re
import time
import unicodedata
from collections import Counter, defaultdict
from pathlib import Path
from urllib.parse import urlencode
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "backend" / "src" / "main" / "resources" / "data"
CATALOG = DATA_DIR / "place_catalog_v11.csv"
AI_CATALOG = DATA_DIR / "ai_place_catalog_v11.csv"
AI_FEATURES = DATA_DIR / "ai_place_features_v11.csv"
PREVIEW = DATA_DIR / "place_catalog_v11_completion_preview.csv"
SEED = DATA_DIR / "place_seed_v11_canonical_import.csv"
CATEGORY_TAXONOMY = DATA_DIR / "place_category_taxonomy_v11.csv"
CACHE = DATA_DIR / ".place_catalog_v11_geocode_cache.json"

EXTERNAL_SOURCE = "tour_places_v11"
USER_AGENT = "GoMate thesis place catalog completion (local data prep)"

CATEGORY_DEFINITIONS = {
    "food": ("Ăn uống", "Quán ăn, cà phê và điểm dừng chân"),
    "market": ("Chợ và mua sắm", "Chợ, khu mua sắm và đặc sản địa phương"),
    "lake": ("Hồ và cảnh quan", "Hồ, sông, bàu, phá và cảnh quan mặt nước"),
    "heritage": ("Di tích và văn hóa", "Di tích, kiến trúc, bảo tàng và không gian tâm linh"),
    "nature": ("Thiên nhiên", "Biển, núi, thác, suối, hang, đảo, rừng và cảnh quan tự nhiên"),
    "landmark": ("Điểm tham quan", "Điểm check-in, khu du lịch, công viên và điểm vui chơi"),
}

DESTINATION_CONTEXTS = {
    "da_lat": [
        "Đà Lạt, Lâm Đồng, Việt Nam",
        "Lâm Đồng, Việt Nam",
    ],
    "vung_tau": [
        "Vũng Tàu, Bà Rịa - Vũng Tàu, Việt Nam",
        "Bà Rịa - Vũng Tàu, Việt Nam",
    ],
    "ha_noi": [
        "Hà Nội, Việt Nam",
        "Sa Pa, Lào Cai, Việt Nam",
        "Ninh Bình, Việt Nam",
        "Quảng Ninh, Việt Nam",
        "Hòa Bình, Việt Nam",
        "Vĩnh Phúc, Việt Nam",
    ],
    "da_nang_hue_hoi_an": [
        "Đà Nẵng, Việt Nam",
        "Huế, Việt Nam",
        "Hội An, Quảng Nam, Việt Nam",
        "Quảng Nam, Việt Nam",
        "Quảng Trị, Việt Nam",
    ],
    "phan_thiet": [
        "Phan Thiết, Bình Thuận, Việt Nam",
        "Mũi Né, Bình Thuận, Việt Nam",
        "Bình Thuận, Việt Nam",
    ],
}

DESTINATION_ALLOWED_TERMS = {
    "da_lat": ["đà lạt", "lâm đồng", "lâm hà", "bảo lộc"],
    "vung_tau": ["vũng tàu", "bà rịa", "long hải", "hồ tràm", "hồ cốc", "bình châu", "xuyên mộc", "châu đức", "long sơn", "phước hải", "thành phố hồ chí minh", "đồng nai"],
    "ha_noi": ["hà nội", "sa pa", "lào cai", "ninh bình", "quảng ninh", "hòa bình", "mai châu", "vĩnh phúc", "phú thọ", "hưng yên", "hạ long", "ba vì", "yên tử"],
    "da_nang_hue_hoi_an": ["đà nẵng", "huế", "thừa thiên huế", "hội an", "quảng nam", "quảng trị", "sơn trà", "cẩm thanh"],
    "phan_thiet": ["phan thiết", "bình thuận", "mũi né", "hàm thuận", "hàm tiến", "kê gà", "lâm đồng"],
}

FORCE_ACCEPT_ALIAS_TOP = {
    "da_lat:ho_vo_cuc",
    "da_lat:nac_thang_thien_duong",
    "da_lat:nha_tho_con_ga",
    "da_lat:xuong_to_lua",
    "da_nang_hue_hoi_an:cau_tinh_yeu_da_nang",
    "da_nang_hue_hoi_an:dai_noi_hue",
    "da_nang_hue_hoi_an:doi_vong_canh",
    "ha_noi:ho_dai_lai",
    "ha_noi:ban_cat_cat",
    "ha_noi:lang_gom_bat_trang",
    "phan_thiet:bau_trang",
    "phan_thiet:bien_mui_ne",
    "phan_thiet:nui_ta_cu",
    "phan_thiet:thap_cham_poshanu",
    "vung_tau:bai_bien_298",
    "vung_tau:bien_long_hai",
    "vung_tau:dai_tong_lam",
    "vung_tau:dao_long_son",
    "vung_tau:doi_cuu_suoi_nghe",
    "vung_tau:marina_vung_tau",
    "vung_tau:nui_minh_dam",
    "vung_tau:thien_vien_thuong_chieu",
}

ALIASES = {
    "da_lat:bao_tang_madame_de": ["Lãnh địa Đức Bà Đà Lạt", "Bảo tàng Madame De Đà Lạt"],
    "da_lat:cafe_mien_du_muc": ["Miền Du Mục Đà Lạt", "Cafe Miền Du Mục Đà Lạt"],
    "da_lat:canh_dong_hoa_cam_tu_cau": ["Cánh đồng hoa cẩm tú cầu Trại Mát Đà Lạt"],
    "da_lat:cong_troi_bali_green_hill": ["Bali Green Hills Đà Lạt", "Bali Green Hill Đà Lạt", "Cổng trời Bali Đà Lạt"],
    "da_lat:dai_bao_thap_kinh_luan": ["Đại Bảo Tháp Kinh Luân Samten Hills", "Samten Hills Đà Lạt"],
    "da_lat:dapa_hill": ["Dapa Hill Đà Lạt", "DaPa Hill Đà Lạt"],
    "da_lat:doi_robin": ["Đồi Robin Đà Lạt", "Robin Hill Đà Lạt"],
    "da_lat:fresh_garden": ["Fresh Garden Dalat", "Fresh Garden Đà Lạt", "Fresh Đà Lạt"],
    "da_lat:gallery_la_chocotea": ["La Chocotea Đà Lạt", "Gallery La Chocotea Đà Lạt"],
    "da_lat:ho_vo_cuc": ["Hồ Vô Cực Đà Lạt", "Infinity Lake Dalat", "Đường hầm đất sét hồ vô cực"],
    "da_lat:hoa_son_dien_trang": ["Hoa Sơn Điền Trang Đà Lạt"],
    "da_lat:kdl_suoi_binh_yen": ["Khu du lịch Suối Bình Yên Đà Lạt", "Suối Bình Yên Lâm Đồng"],
    "da_lat:kombi_land": ["Kombi Land Đà Lạt"],
    "da_lat:lac_hu_co_tran": ["Lạc Hư Cổ Trấn Đà Lạt"],
    "da_lat:lang_art_cafe": ["Lặng Art Cafe Đà Lạt", "Lặng Art Café Đà Lạt"],
    "da_lat:nac_thang_thien_duong": ["Nấc thang thiên đường Đà Lạt", "Sunny Farm Đà Lạt"],
    "da_lat:nha_tho_con_ga": ["Nhà thờ chính tòa Đà Lạt", "Nhà thờ Con Gà Đà Lạt", "Dalat Cathedral"],
    "da_lat:nong_trai_co_tich": ["Fairytale Land Đà Lạt", "Nông trại cổ tích Đà Lạt"],
    "da_lat:que_garden": ["Que Garden Đà Lạt"],
    "da_lat:rung_hoa_kho": ["Rừng hoa Đà Lạt", "Rừng hoa khô Đà Lạt"],
    "da_lat:thac_pongour": ["Pongour waterfall Lâm Đồng", "Thác Pongour Đức Trọng"],
    "da_lat:thi_tran_iyashi": ["Iyashi Đà Lạt", "Thị trấn Iyashi Đà Lạt"],
    "da_lat:tiem_nuong_chuyen_tau_hoang_hon": ["Tiệm nướng chuyến tàu hoàng hôn Đà Lạt"],
    "da_lat:tu_vien_bat_nha": ["Tu viện Bát Nhã Bảo Lộc", "Bat Nha Monastery Bao Loc"],
    "da_lat:vuon_chau_au": ["Vườn Châu Âu Đà Lạt", "Euro Garden Đà Lạt"],
    "da_lat:vuon_dia_dang": ["Vườn Địa Đàng Đà Lạt"],
    "da_lat:xuong_to_lua": ["XQ Sử Quán Đà Lạt", "XQ Historical Village Đà Lạt", "Xưởng tơ lụa Đà Lạt"],
    "da_nang_hue_hoi_an:bien_an_bang": ["An Bang Beach Hội An", "An Bang Beach Hoi An"],
    "da_nang_hue_hoi_an:bien_cua_dai": ["Cua Dai Beach Hội An", "Cua Dai Beach Hoi An"],
    "da_nang_hue_hoi_an:bien_my_khe": ["My Khe Beach Đà Nẵng", "My Khe Beach Da Nang"],
    "da_nang_hue_hoi_an:cau_tinh_yeu_da_nang": ["Love Bridge Đà Nẵng", "Da Nang Love Bridge"],
    "da_nang_hue_hoi_an:dai_noi_hue": ["Hoàng Thành Huế", "Imperial City Huế", "Hue Imperial City"],
    "da_nang_hue_hoi_an:doi_vong_canh": ["Vong Canh Hill Huế", "Đồi Vọng Cảnh Huế"],
    "da_nang_hue_hoi_an:chua_cau_hoi_an": ["Chùa Cầu Hội An", "Japanese Covered Bridge Hội An"],
    "da_nang_hue_hoi_an:hoi_quan_phuc_kien": ["Hội quán Phúc Kiến Hội An", "Fujian Assembly Hall Hoi An"],
    "da_nang_hue_hoi_an:nha_co_tan_ky": ["Nhà cổ Tấn Ký Hội An", "Tan Ky Old House Hoi An", "Tan Ky House Hoi An"],
    "da_nang_hue_hoi_an:rung_dua_bay_mau": ["Rừng dừa Bảy Mẫu Cẩm Thanh Hội An"],
    "da_nang_hue_hoi_an:thanh_dia_la_vang": ["Thánh địa La Vang Quảng Trị", "La Vang Holy Land Quang Tri", "Our Lady of La Vang"],
    "ha_noi:ban_cat_cat": ["Bản Cát Cát Sa Pa", "Cat Cat Village Sapa", "Cat Cat tourism village Sapa"],
    "ha_noi:ban_lac": ["Bản Lác Mai Châu"],
    "ha_noi:ho_dai_lai": ["Hồ Đại Lải Vĩnh Phúc", "Dai Lai Lake Vinh Phuc"],
    "ha_noi:lang_co_duong_lam": ["Làng cổ Đường Lâm Sơn Tây", "Làng cổ Đường Lâm Hà Nội", "Duong Lam Ancient Village Son Tay"],
    "ha_noi:lang_gom_bat_trang": ["Làng gốm Bát Tràng Hà Nội", "Bat Trang Pottery Village", "Trung tâm Tinh hoa làng nghề Việt Bát Tràng"],
    "ha_noi:moana_sapa": ["Moana Sapa Lào Cai"],
    "ha_noi:nha_tho_da_sapa": ["Nhà thờ đá Sa Pa", "Sapa Stone Church", "Notre Dame Cathedral Sapa"],
    "ha_noi:pho_co_ha_noi": ["Phố cổ Hà Nội", "Hanoi Old Quarter"],
    "ha_noi:tuan_chau": ["Tuần Châu Hạ Long"],
    "ha_noi:yen_tu": ["Yên Tử Quảng Ninh"],
    "phan_thiet:bai_da_ong_dia": ["Bãi đá Ông Địa Mũi Né"],
    "phan_thiet:bao_tang_ngoc_trai": ["Bảo tàng ngọc trai Mũi Né", "Long Beach Pearl Museum Mui Ne"],
    "phan_thiet:bau_sen": ["Bàu Sen Bình Thuận"],
    "phan_thiet:bau_trang": ["Bàu Trắng Bình Thuận", "White Sand Dunes Mui Ne"],
    "phan_thiet:bien_mui_ne": ["Mũi Né Beach", "Mui Ne Beach"],
    "phan_thiet:circus_land": ["Circus Land NovaWorld Phan Thiết"],
    "phan_thiet:cong_vien_bikini_beach": ["Bikini Beach NovaWorld Phan Thiết"],
    "phan_thiet:doi_cat_bay": ["Đồi Cát Bay Mũi Né", "Đồi cát đỏ Mũi Né"],
    "phan_thiet:hon_rom": ["Hòn Rơm Mũi Né"],
    "phan_thiet:lau_ong_hoang": ["Lầu Ông Hoàng Phan Thiết"],
    "phan_thiet:mui_ke_ga": ["Mũi Kê Gà Bình Thuận"],
    "phan_thiet:nui_ta_cu": ["Núi Tà Kóu", "Núi Tà Cú Bình Thuận", "Ta Cu Mountain"],
    "phan_thiet:thap_cham_poshanu": ["Tháp Chăm Poshanu Phan Thiết", "Po Sah Inu Cham Towers", "Po Shanu Cham Towers"],
    "vung_tau:bai_bien_298": ["Bãi biển 298 Vũng Tàu"],
    "vung_tau:bien_ho_coc": ["Hồ Cốc Beach", "Ho Coc Beach"],
    "vung_tau:bien_long_hai": ["Long Hai Beach"],
    "vung_tau:bien_tropicana": ["Tropicana Park Hồ Tràm", "Tropicana Hồ Tràm"],
    "vung_tau:cau_ngam_bien_hamptons": ["Hamptons Pier Hồ Tràm", "Hamptons Hồ Tràm pier"],
    "vung_tau:cau_tinh_yeu_long_hai": ["Cầu Tình Yêu Long Hải"],
    "vung_tau:cong_vien_rung_minera": ["Minera Hot Springs Bình Châu"],
    "vung_tau:dai_tong_lam": ["Đại Tòng Lâm Bà Rịa Vũng Tàu"],
    "vung_tau:dao_long_son": ["Đảo Long Sơn Vũng Tàu", "Long Son Island Vung Tau", "Xã Long Sơn Vũng Tàu"],
    "vung_tau:doi_cuu_suoi_nghe": ["Đồi cừu Suối Nghệ", "Suoi Nghe Sheep Farm"],
    "vung_tau:ho_may": ["Hồ Mây Park Vũng Tàu", "Ho May Park Vung Tau"],
    "vung_tau:ho_suoi_mo_binh_chau": ["Hồ Suối Mơ Bình Châu"],
    "vung_tau:kdl_bien_dong": ["Khu du lịch Biển Đông Vũng Tàu"],
    "vung_tau:kdl_ngoc_xuong": ["Khu du lịch Ngọc Xương Long Hải"],
    "vung_tau:khu_gieng_troi_binh_chau": ["Giếng trời Bình Châu"],
    "vung_tau:lang_ca_ong": ["Lăng Cá Ông Vũng Tàu", "Whale Temple Vung Tau"],
    "vung_tau:marina_vung_tau": ["Bến thuyền Marina Vũng Tàu", "Vung Tau Marina"],
    "vung_tau:ngon_hai_dang_vung_tau": ["Vũng Tàu Lighthouse", "Ngọn Hải Đăng Vũng Tàu"],
    "vung_tau:nong_trai_cuu": ["Nông trại cừu Suối Nghệ", "Suoi Nghe Sheep Farm"],
    "vung_tau:nui_minh_dam": ["Núi Minh Đạm Long Hải", "Minh Dam Base Long Hai", "Minh Dam Mountain"],
    "vung_tau:thap_vong_thien": ["Tháp vọng thiên Vũng Tàu"],
    "vung_tau:thien_vien_thuong_chieu": ["Thiền viện Thường Chiếu Long Thành", "Thuong Chieu Monastery"],
    "vung_tau:thien_vien_truc_lam_chan_nguyen": ["Thiền viện Trúc Lâm Chân Nguyên Vũng Tàu"],
    "vung_tau:tuong_chua_kito": ["Christ the King Vũng Tàu", "Christ of Vung Tau"],
}


def norm(value):
    value = (value or "").lower().strip()
    value = unicodedata.normalize("NFD", value)
    value = "".join(ch for ch in value if unicodedata.category(ch) != "Mn")
    value = value.replace("đ", "d")
    value = re.sub(r"[^a-z0-9]+", " ", value)
    return re.sub(r"\s+", " ", value).strip()


def read_csv(path):
    with path.open(encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def write_csv(path, rows, fieldnames):
    with path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, quoting=csv.QUOTE_ALL)
        writer.writeheader()
        writer.writerows(rows)


def category_for(name):
    n = norm(name)
    if any(k in n for k in ["cafe", "ca phe", "tiem nuong"]):
        return "food"
    if n.startswith("cho ") or " cho " in f" {n} ":
        return "market"
    if any(k in n for k in ["ho ", "song ", "bau ", "pha ", "suoi tien"]):
        return "lake"
    if any(k in n for k in [
        "chua", "thien vien", "den ", "nha tho", "dinh ", "lang ", "bao tang",
        "van mieu", "dai noi", "thanh dia", "thap", "nha tu", "nha hat",
        "hoi quan", "lang co", "lang gom", "duc thanh", "bach dinh",
        "dinh co", "lang ca ong", "tuong chua", "niet ban", "dai tong lam",
        "nha lon", "hoa lu", "pho co", "chua cau", "lau ong hoang",
    ]):
        return "heritage"
    if any(k in n for k in [
        "bien", "bai ", "ban dao", "deo", "doi ", "thac", "nui", "vuon quoc gia",
        "hang", "dong ", "rung", "suoi", "hon ", "dao", "cu lao", "mui ",
        "tam coc", "trang an", "vinh ", "lang chai", "canh dong", "bai da",
    ]):
        return "nature"
    return "landmark"


def nominatim_search(query, cache):
    key = f"nominatim::{query}"
    if key in cache:
        return cache[key]
    params = urlencode({
        "q": query,
        "format": "jsonv2",
        "addressdetails": "1",
        "namedetails": "1",
        "extratags": "1",
        "limit": "5",
        "countrycodes": "vn",
    })
    req = Request(
        f"https://nominatim.openstreetmap.org/search?{params}",
        headers={"User-Agent": USER_AGENT},
    )
    with urlopen(req, timeout=12) as resp:
        data = json.loads(resp.read().decode("utf-8"))
    cache[key] = data
    CACHE.write_text(json.dumps(cache, ensure_ascii=False, indent=2), encoding="utf-8")
    time.sleep(1.05)
    return data


def targeted_contexts(row):
    destination = row["destination_key"]
    name = norm(row["canonical_name"])
    if destination == "ha_noi":
        if any(k in name for k in ["sa pa", "sapa", "fansipan", "cat cat", "moana", "nha tho da"]):
            return ["Sa Pa, Lào Cai, Việt Nam", "Lào Cai, Việt Nam"]
        if any(k in name for k in ["ha long", "tuan chau", "thien cung", "sung sot", "yen tu"]):
            return ["Hạ Long, Quảng Ninh, Việt Nam", "Quảng Ninh, Việt Nam"]
        if any(k in name for k in ["bai dinh", "hang mua", "hoa lu", "tam coc", "trang an"]):
            return ["Ninh Bình, Việt Nam"]
        if any(k in name for k in ["ban lac", "mai chau"]):
            return ["Mai Châu, Hòa Bình, Việt Nam", "Hòa Bình, Việt Nam"]
        if "dai lai" in name:
            return ["Đại Lải, Vĩnh Phúc, Việt Nam", "Vĩnh Phúc, Việt Nam"]
        return ["Hà Nội, Việt Nam"]
    if destination == "da_nang_hue_hoi_an":
        if any(k in name for k in ["hue", "dong ba", "thien mu", "dai noi", "vong canh", "khai dinh", "minh mang", "tu duc", "song huong", "tam giang", "lang huong"]):
            return ["Huế, Việt Nam", "Thừa Thiên Huế, Việt Nam"]
        if any(k in name for k in ["hoi an", "an bang", "cua dai", "cu lao cham", "phuc kien", "tan ky", "bay mau", "song hoai", "my son"]):
            return ["Hội An, Quảng Nam, Việt Nam", "Quảng Nam, Việt Nam"]
        if "la vang" in name:
            return ["La Vang, Quảng Trị, Việt Nam", "Quảng Trị, Việt Nam"]
        return ["Đà Nẵng, Việt Nam"]
    if destination == "phan_thiet":
        if any(k in name for k in ["mui ne", "hon rom", "doi cat", "bai da", "lang chai"]):
            return ["Mũi Né, Bình Thuận, Việt Nam", "Phan Thiết, Bình Thuận, Việt Nam"]
        return ["Phan Thiết, Bình Thuận, Việt Nam", "Bình Thuận, Việt Nam"]
    if destination == "vung_tau":
        if any(k in name for k in ["ho tram", "ho coc", "binh chau"]):
            return ["Xuyên Mộc, Bà Rịa - Vũng Tàu, Việt Nam", "Bà Rịa - Vũng Tàu, Việt Nam"]
        if any(k in name for k in ["long hai", "minh dam", "phuoc hai"]):
            return ["Long Hải, Bà Rịa - Vũng Tàu, Việt Nam", "Bà Rịa - Vũng Tàu, Việt Nam"]
        return ["Vũng Tàu, Bà Rịa - Vũng Tàu, Việt Nam", "Bà Rịa - Vũng Tàu, Việt Nam"]
    return DESTINATION_CONTEXTS[destination][:2]


def candidate_queries(row):
    name = row["canonical_name"]
    external_id = row["external_id"]
    explicit = ALIASES.get(external_id, [])
    queries = []
    queries.extend(explicit)
    for context in targeted_contexts(row):
        queries.append(f"{name}, {context}")
    queries.append(f"{name}, Việt Nam")
    seen = set()
    result = []
    for q in queries:
        qn = norm(q)
        if qn not in seen:
            seen.add(qn)
            result.append(q)
    return result


def result_name(result):
    namedetails = result.get("namedetails") or {}
    for key in ("name:vi", "name", "official_name", "alt_name"):
        value = namedetails.get(key)
        if value:
            return value
    return result.get("name") or result.get("display_name", "").split(",")[0]


def valid_for_destination(result, destination):
    display = (result.get("display_name") or "").lower()
    if (result.get("address") or {}).get("country_code") != "vn":
        return False
    return any(term in display for term in DESTINATION_ALLOWED_TERMS[destination])


def acceptable_match(row, query, result):
    if not valid_for_destination(result, row["destination_key"]):
        return False
    if row["external_id"] in FORCE_ACCEPT_ALIAS_TOP and query in ALIASES.get(row["external_id"], []):
        return True
    display_norm = norm(result.get("display_name", ""))
    name_norm = norm(row["canonical_name"])
    result_norm = norm(result_name(result))
    query_head = norm(query.split(",")[0])
    if name_norm and name_norm in display_norm:
        return True
    if query_head and query_head in display_norm:
        return True
    if result_norm and (result_norm in name_norm or name_norm in result_norm):
        return True
    # For explicit aliases, accept the result when the alias head is present in result display.
    if query in ALIASES.get(row["external_id"], []) and query_head and query_head in display_norm:
        return True
    return False


def extract_province(result, destination):
    address = result.get("address") or {}
    for key in ("city", "state", "province", "county", "region"):
        value = address.get(key)
        if value and any(term in value.lower() for term in DESTINATION_ALLOWED_TERMS[destination]):
            return value
    if destination == "da_lat":
        return "Lâm Đồng"
    if destination == "vung_tau":
        return "Bà Rịa - Vũng Tàu"
    if destination == "phan_thiet":
        return "Bình Thuận"
    if destination == "ha_noi":
        for term, province in [
            ("lào cai", "Lào Cai"), ("sa pa", "Lào Cai"), ("ninh bình", "Ninh Bình"),
            ("quảng ninh", "Quảng Ninh"), ("hòa bình", "Hòa Bình"), ("vĩnh phúc", "Vĩnh Phúc"),
            ("hà nội", "Hà Nội"),
        ]:
            if term in (result.get("display_name") or "").lower():
                return province
    if destination == "da_nang_hue_hoi_an":
        for term, province in [
            ("đà nẵng", "Đà Nẵng"), ("huế", "Thừa Thiên Huế"), ("thừa thiên", "Thừa Thiên Huế"),
            ("hội an", "Quảng Nam"), ("quảng nam", "Quảng Nam"), ("quảng trị", "Quảng Trị"),
        ]:
            if term in (result.get("display_name") or "").lower():
                return province
    return address.get("state") or address.get("province") or ""


def extract_district(result):
    address = result.get("address") or {}
    return (
        address.get("city")
        or address.get("town")
        or address.get("municipality")
        or address.get("county")
        or address.get("suburb")
        or ""
    )


def geocode(row, cache):
    if row.get("latitude") and row.get("longitude"):
        return {
            "status": "verified_existing",
            "latitude": row["latitude"],
            "longitude": row["longitude"],
            "address": row.get("address", ""),
            "province": row.get("province", ""),
            "district": row.get("district", ""),
            "source": "existing_catalog",
            "reference": "",
            "license": "",
            "query": "",
        }
    for query in candidate_queries(row):
        try:
            results = nominatim_search(query, cache)
        except Exception as exc:
            return {"status": "geocode_error", "error": str(exc), "query": query}
        for result in results:
            if acceptable_match(row, query, result):
                return {
                    "status": "verified_nominatim",
                    "latitude": f"{float(result['lat']):.7f}",
                    "longitude": f"{float(result['lon']):.7f}",
                    "address": result.get("display_name", ""),
                    "province": extract_province(result, row["destination_key"]),
                    "district": extract_district(result),
                    "source": "OpenStreetMap/Nominatim",
                    "reference": f"https://www.openstreetmap.org/{result.get('osm_type')}/{result.get('osm_id')}",
                    "license": "OpenStreetMap contributors / ODbL",
                    "query": query,
                    "osm_type": result.get("osm_type", ""),
                    "osm_id": result.get("osm_id", ""),
                    "class": result.get("category") or result.get("class", ""),
                    "type": result.get("type", ""),
                }
    return {"status": "unresolved", "query": " | ".join(candidate_queries(row))}


def main():
    rows = read_csv(CATALOG)
    cache = {}
    if CACHE.exists():
        cache = json.loads(CACHE.read_text(encoding="utf-8"))

    enriched = []
    preview_rows = []
    for row in rows:
        row = dict(row)
        row["external_source"] = EXTERNAL_SOURCE
        category = row.get("category") or category_for(row["canonical_name"])
        row["category"] = category
        geo = geocode(row, cache)
        if geo.get("latitude") and geo.get("longitude"):
            row["latitude"] = geo["latitude"]
            row["longitude"] = geo["longitude"]
            row["address"] = row.get("address") or geo.get("address", "")
            row["province"] = row.get("province") or geo.get("province", "")
            row["district"] = row.get("district") or geo.get("district", "")
        enriched.append(row)
        preview_rows.append({
            "external_id": row["external_id"],
            "destination_key": row["destination_key"],
            "canonical_name": row["canonical_name"],
            "category": row["category"],
            "province": row.get("province", ""),
            "district": row.get("district", ""),
            "latitude": row.get("latitude", ""),
            "longitude": row.get("longitude", ""),
            "geocode_status": geo.get("status", ""),
            "geocode_query": geo.get("query", ""),
            "geocode_source": geo.get("source", ""),
            "geocode_reference": geo.get("reference", ""),
            "geocode_license": geo.get("license", ""),
            "osm_type": geo.get("osm_type", ""),
            "osm_id": geo.get("osm_id", ""),
            "osm_class": geo.get("class", ""),
            "osm_place_type": geo.get("type", ""),
            "review_note": "" if row.get("latitude") and row.get("longitude") else "missing verified coordinate; do not import while places.latitude/longitude are NOT NULL",
        })

    CATALOG.write_text("", encoding="utf-8")
    fieldnames = [
        "external_source", "external_id", "destination_key", "canonical_name", "category",
        "province", "district", "address", "latitude", "longitude",
        "image_source_url", "image_source_page", "image_license",
    ]
    write_csv(CATALOG, enriched, fieldnames)

    ai_rows = [
        {
            "external_id": r["external_id"],
            "canonical_name": r["canonical_name"],
            "destination_key": r["destination_key"],
        }
        for r in enriched
    ]
    write_csv(AI_CATALOG, ai_rows, ["external_id", "canonical_name", "destination_key"])

    feature_rows = [
        {
            "external_id": r["external_id"],
            "canonical_name": r["canonical_name"],
            "destination_key": r["destination_key"],
            "category": r.get("category", ""),
            "province": r.get("province", ""),
            "latitude": r.get("latitude", ""),
            "longitude": r.get("longitude", ""),
        }
        for r in enriched
    ]
    write_csv(AI_FEATURES, feature_rows, [
        "external_id", "canonical_name", "destination_key", "category", "province", "latitude", "longitude",
    ])

    write_csv(PREVIEW, preview_rows, [
        "external_id", "destination_key", "canonical_name", "category", "province", "district",
        "latitude", "longitude", "geocode_status", "geocode_query", "geocode_source",
        "geocode_reference", "geocode_license", "osm_type", "osm_id", "osm_class",
        "osm_place_type", "review_note",
    ])

    seed_rows = []
    for r in enriched:
        if not (r.get("latitude") and r.get("longitude")):
            continue
        category_name, category_description = CATEGORY_DEFINITIONS[r["category"]]
        seed_rows.append({
            "name": r["canonical_name"],
            "category_code": r["category"],
            "category_name": category_name,
            "category_description": category_description,
            "description": "",
            "province": r.get("province", ""),
            "district": r.get("district", ""),
            "address": r.get("address", ""),
            "latitude": r["latitude"],
            "longitude": r["longitude"],
            "source_type": "EXTERNAL_API",
            "external_source": r["external_source"],
            "external_id": r["external_id"],
            "image_source_url": r.get("image_source_url", ""),
            "image_source_page": r.get("image_source_page", ""),
            "image_license": r.get("image_license", ""),
            "image_attribution": "",
            "image_caption": "",
        })
    write_csv(SEED, seed_rows, [
        "name", "category_code", "category_name", "category_description", "description",
        "province", "district", "address", "latitude", "longitude", "source_type",
        "external_source", "external_id", "image_source_url", "image_source_page",
        "image_license", "image_attribution", "image_caption",
    ])

    cat_counts = Counter(r.get("category", "") for r in enriched)
    taxonomy_rows = [
        {
            "category_code": code,
            "category_name": name,
            "definition": definition,
            "place_count": cat_counts.get(code, 0),
        }
        for code, (name, definition) in CATEGORY_DEFINITIONS.items()
    ]
    write_csv(CATEGORY_TAXONOMY, taxonomy_rows, [
        "category_code", "category_name", "definition", "place_count",
    ])

    CACHE.write_text(json.dumps(cache, ensure_ascii=False, indent=2), encoding="utf-8")

    by_dest = defaultdict(list)
    for r in enriched:
        by_dest[r["destination_key"]].append(r)
    print("catalog_rows", len(enriched))
    print("unique_external_id", len({r["external_id"] for r in enriched}))
    print("seed_rows", len(seed_rows))
    print("category_counts", dict(cat_counts))
    for dest in sorted(by_dest):
        group = by_dest[dest]
        print(
            dest,
            "total", len(group),
            "coords", sum(1 for r in group if r.get("latitude") and r.get("longitude")),
            "unresolved", sum(1 for r in group if not (r.get("latitude") and r.get("longitude"))),
        )


if __name__ == "__main__":
    main()
