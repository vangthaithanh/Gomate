# Map demo places setup

Ngay cap nhat: 2026-09-19

## Muc tieu

Them nhanh du lieu dia diem demo de tiep tuc cau hinh marker, search va route tren Mapbox. Tai thoi diem hien tai day la tai lieu lich su cua Map Foundation; luong Map active da dung Place API that.

Hien tai repo da co Place V2 va seed that trong PostgreSQL. Khong them dependency moi vao demo data cho production.

## Noi da them dia diem demo

Flutter marker/search/detail demo cu:

```text
lib/features/map/data/demo_places.dart
lib/features/map/data/demo_place_data_source.dart
```

Backend route active:

```text
RouteService -> PlaceCoordinateResolver -> PlaceRepository -> PostgreSQL places
```

Trang thai hien tai:

- `GoMateMapScreen` active dung `SpringGoMateMapGateway`, khong dung `demoPlaces` cho marker/search/detail.
- Backend routing khong con `DemoPlaceCatalog`.
- Route request mac dinh dung GPS runtime `originLatitude` + `originLongitude` va `destinationPlaceId` that; khi user chon diem bat dau khac thi dung `originPlaceId` + `destinationPlaceId`.
- Neu Place khong ton tai/khong ACTIVE, backend tra loi co kiem soat thay vi fallback ve demo coordinate.

## Dia diem demo moi

```text
place-109
name: Thung lung Tinh Yeu
longitude: 108.4505
latitude: 11.9803
category: nature
```

```text
place-110
name: Doi che Cau Dat
longitude: 108.5763
latitude: 11.9173
category: nature
```

## Luu y kien truc

Day la du lieu demo tam thoi cho Map foundation va chi nen giu cho luong demo cu.

Luong production hien tai:

```text
Flutter -> Spring Boot /api/v1/places -> PostgreSQL places/place_media
Flutter -> Spring Boot /api/v1/routes/directions -> PostgreSQL places -> Mapbox Directions
```

Da thay:

- `DemoPlaceDataSource` bang data source goi API Place trong `GoMateMapScreen`.
- `DemoPlaceCatalog` bang `PlaceCoordinateResolver`.

Con lai:

- `demo_places.dart` va `DemoGoMateMapGateway` van ton tai cho cac luong demo cu.
- `demoTripStopIds` se duoc thay bang Trip/TripStop API o task Trip sau nay.

## Media

Chua gan anh Cloudinary cho 2 dia diem nay trong buoc nay. Theo luong media da chot, Place media sau nay se vao `place_media`, khong tao bang media tong quat.
