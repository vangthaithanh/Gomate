package vn.gomate.common;

import java.sql.*;
import java.util.*;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

/** SQL luôn tham số hóa. Chuẩn hoá tên cột snake_case thành JSON camelCase. */
@Repository
public class Db {
    private final NamedParameterJdbcTemplate jdbc;
    public Db(NamedParameterJdbcTemplate jdbc) { this.jdbc = jdbc; }
    public int update(String sql, Map<String, ?> args) { return jdbc.update(sql, args); }
    public List<Map<String, Object>> list(String sql, Map<String, ?> args) {
        return jdbc.query(sql, args, (rs, row) -> {
            Map<String, Object> result = new LinkedHashMap<>();
            for (int i = 1; i <= rs.getMetaData().getColumnCount(); i++) {
                String label = rs.getMetaData().getColumnLabel(i).toLowerCase(Locale.ROOT);
                StringBuilder key = new StringBuilder(); boolean upper = false;
                for (char c : label.toCharArray()) {
                    if (c == '_') { upper = true; continue; }
                    key.append(upper ? Character.toUpperCase(c) : c); upper = false;
                }
                Object v = rs.getObject(i);
                if (v instanceof Timestamp t) v = t.toLocalDateTime();
                else if (v instanceof java.sql.Date d) v = d.toLocalDate();
                result.put(key.toString(), v);
            }
            return result;
        });
    }
    public Map<String, Object> one(String sql, Map<String, ?> args) {
        var rows = list(sql, args); if (rows.isEmpty()) throw ApiException.notFound(); return rows.get(0);
    }
    public long count(String sql, Map<String, ?> args) { return jdbc.queryForObject(sql, args, Long.class); }
    public static Map<String, Object> args(Object... pairs) {
        Map<String, Object> map = new HashMap<>();
        for (int i = 0; i < pairs.length; i += 2) map.put((String) pairs[i], pairs[i + 1]);
        return map;
    }
}
