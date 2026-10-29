package vn.gomate.common;

import java.text.Normalizer;
import java.util.Locale;

/** Search-only folding; never use this to change account/business identity. */
public final class SearchText {
    private SearchText() {}
    private static final String ACCENTS="àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ";
    private static final String ASCII="aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd";
    public static String fold(String value) {
        return Normalizer.normalize(value==null?"":value,Normalizer.Form.NFD)
            .replaceAll("\\p{M}+", "").replace('đ','d').replace('Đ','D')
            .trim().replaceAll("\\s+"," ").toLowerCase(Locale.ROOT);
    }
    public static String sql(String expression) {
        return "TRANSLATE(LOWER(COALESCE("+expression+",'')),'"+ACCENTS+"\u0300\u0301\u0303\u0309\u0323\u0302\u0306\u031b','"+ASCII+"')";
    }
    public static String contains(String value) {
        return "%"+fold(value).replace("!","!!").replace("%","!%").replace("_","!_")+"%";
    }
    public static String query(String value) {
        String clean=value==null?"":value.trim().replaceAll("\\s+"," ");
        if(clean.length()>200) throw ApiException.bad("Từ khóa tối đa 200 ký tự.");
        return clean;
    }
}
