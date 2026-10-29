package vn.gomate.user.service;

import java.util.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vn.gomate.common.*;
import vn.gomate.user.repository.RecentSearchRepository;

@Service
public class RecentSearchService {
    private final RecentSearchRepository repo;
    public RecentSearchService(RecentSearchRepository repo) {this.repo=repo;}
    public List<String> list(UUID viewer) {
        return repo.list(viewer);
    }
    @Transactional public List<String> submit(UUID viewer,String query) {
        String clean=SearchText.query(query), key=SearchText.fold(clean);
        if(key.isEmpty()) throw ApiException.bad("Từ khóa không được trống.");
        repo.lock(viewer);
        repo.remove(viewer,key);
        repo.insert(viewer,key,clean);
        return list(viewer);
    }
    @Transactional public void remove(UUID viewer,String query) {
        repo.lock(viewer);
        repo.remove(viewer,SearchText.fold(SearchText.query(query)));
    }
}
