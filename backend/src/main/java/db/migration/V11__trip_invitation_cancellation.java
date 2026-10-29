package db.migration;

import java.sql.*;
import java.util.ArrayList;
import org.flywaydb.core.api.migration.BaseJavaMigration;
import org.flywaydb.core.api.migration.Context;

public class V11__trip_invitation_cancellation extends BaseJavaMigration {
 @Override
 public void migrate(Context context) throws Exception {
  Connection connection=context.getConnection();
  var constraints=new ArrayList<String>();
  // V9's unnamed CHECK has different generated names in PostgreSQL and H2.
  try(PreparedStatement query=connection.prepareStatement("""
   SELECT tc.constraint_name
   FROM information_schema.table_constraints tc
   JOIN information_schema.check_constraints cc
    ON cc.constraint_catalog=tc.constraint_catalog
    AND cc.constraint_schema=tc.constraint_schema AND cc.constraint_name=tc.constraint_name
   WHERE LOWER(tc.table_name)='trip_invitations' AND tc.table_schema=?
    AND tc.constraint_type='CHECK' AND LOWER(cc.check_clause) LIKE '%status%'
    AND LOWER(cc.check_clause) LIKE '%pending%'
   """)) {
   query.setString(1,connection.getSchema());
   try(ResultSet rows=query.executeQuery()) {
    while(rows.next()) constraints.add(rows.getString(1));
   }
  }
  if(constraints.size()!=1) throw new SQLException("Expected one trip invitation status CHECK; found "+constraints.size());
  try(Statement sql=connection.createStatement()) {
   sql.execute("ALTER TABLE trip_invitations DROP CONSTRAINT \""+constraints.get(0).replace("\"","\"\"")+"\"");
   sql.execute("""
    ALTER TABLE trip_invitations ADD CONSTRAINT ck_trip_invitations_status
    CHECK (status IN ('PENDING','ACCEPTED','DECLINED','CANCELLED'))
    """);
  }
 }
}
