package vn.gomate.place.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.*;
import org.springframework.stereotype.Service;
import vn.gomate.common.*;
import vn.gomate.place.repository.PlaceRepository;

@Service
public class PlaceSearchService {
    private final PlaceRepository repo;
    private final ObjectMapper json;
    public PlaceSearchService(PlaceRepository repo,ObjectMapper json) {this.repo=repo;this.json=json;}
    public record Cursor(String q,List<String> filters,Double lat,Double lng,long id,double distance) {}
    public record Page(List<Map<String,Object>> items,String nextCursor) {}
    public Page search(String query,List<String> filters,Double lat,Double lng,int size,String token) {
        String q=SearchText.fold(SearchText.query(query));
        var selected=filters.stream().filter(f->!f.isBlank()).distinct().sorted().toList();
        if(!Set.of("nature","checkin","history","nearby").containsAll(selected) || size<1 || size>50) throw ApiException.bad("Bộ lọc hoặc kích thước trang không hợp lệ.");
        if(selected.contains("nearby") && (lat==null || lng==null || !Double.isFinite(lat) || !Double.isFinite(lng) || Math.abs(lat)>90 || Math.abs(lng)>180))
            throw new ApiException(400,"SEARCH_LOCATION_REQUIRED","Cần vị trí hiện tại để tìm địa điểm gần bạn.");
        if(!selected.contains("nearby")) {lat=null;lng=null;}
        Cursor cursor=null;
        if(token!=null) try {
            if(token.length()>4096) throw new IllegalArgumentException();
            cursor=json.readValue(Base64.getUrlDecoder().decode(token),Cursor.class);
            if(!q.equals(cursor.q()) || !selected.equals(cursor.filters()) || !Objects.equals(lat,cursor.lat()) || !Objects.equals(lng,cursor.lng()) || cursor.id()<1 || !Double.isFinite(cursor.distance()) || cursor.distance()<0) throw new IllegalArgumentException();
        } catch(Exception e) {throw ApiException.bad("Con trỏ địa điểm không hợp lệ.");}
        var rows=repo.searchPage(q,new HashSet<>(selected),lat,lng,size+1,cursor==null?null:cursor.id(),cursor==null?null:cursor.distance());
        var items=rows.subList(0,Math.min(size,rows.size()));
        String next=null;
        if(rows.size()>size) try {
            var last=items.get(items.size()-1);
            next=Base64.getUrlEncoder().withoutPadding().encodeToString(json.writeValueAsBytes(new Cursor(q,selected,lat,lng,((Number)last.get("placeId")).longValue(),((Number)last.get("distanceKm")).doubleValue())));
        } catch(Exception e) {throw new IllegalStateException(e);}
        return new Page(items,next);
    }
}
