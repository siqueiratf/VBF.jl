-- Storage-only layout. Logical views use built-in SQLite functions; no extension is required.
CREATE TABLE closure_templates(id INTEGER PRIMARY KEY, digest BLOB NOT NULL UNIQUE, body TEXT NOT NULL);
--@statement
CREATE TABLE closure_candidates(id TEXT PRIMARY KEY, lut BLOB, lut_text TEXT, sigma TEXT, apn INTEGER NOT NULL, degree INTEGER NOT NULL, template_id INTEGER NOT NULL REFERENCES closure_templates(id), ortho BLOB NOT NULL, encoding INTEGER NOT NULL CHECK(encoding IN (0,1)), class_id INTEGER, state TEXT NOT NULL, CHECK((lut IS NULL)!=(lut_text IS NULL)));
--@statement
CREATE UNIQUE INDEX candidates_lut ON closure_candidates(lut) WHERE lut IS NOT NULL;
--@statement
CREATE UNIQUE INDEX candidates_lut_text ON closure_candidates(lut_text) WHERE lut_text IS NOT NULL;
--@statement
CREATE INDEX candidates_sigma ON closure_candidates(sigma);
--@statement
CREATE INDEX candidates_counters ON closure_candidates(apn,degree,sigma,class_id);
--@statement
CREATE INDEX candidates_state ON closure_candidates(state);
--@statement
CREATE VIEW candidates AS SELECT c.id,CASE WHEN c.lut IS NULL THEN c.lut_text ELSE lower(hex(c.lut)) END AS lut_hex,c.sigma,c.apn,c.degree,
(SELECT CASE WHEN c.encoding=0 THEN t.body ELSE replace(replace(replace(replace(t.body,'!!vbf:c:lut!!',CASE WHEN c.lut IS NULL THEN c.lut_text ELSE lower(hex(c.lut)) END),'!!vbf:c:id!!',c.id),'!!vbf:c:sigma!!',coalesce(c.sigma,'')),'!!vbf:c:ortho!!',lower(hex(c.ortho))) END FROM closure_templates t WHERE t.id=c.template_id) AS properties,c.class_id,c.state FROM closure_candidates c;
--@statement
CREATE TRIGGER candidates_update INSTEAD OF UPDATE OF class_id,state ON candidates BEGIN UPDATE closure_candidates SET class_id=NEW.class_id,state=NEW.state WHERE id=OLD.id; END;
--@statement
CREATE TRIGGER candidates_evidence_immutable INSTEAD OF UPDATE OF id,lut_hex,sigma,apn,degree,properties ON candidates BEGIN SELECT RAISE(ABORT,'candidate evidence is immutable; insert a new candidate'); END;
--@statement
CREATE TRIGGER candidates_delete INSTEAD OF DELETE ON candidates BEGIN DELETE FROM closure_candidates WHERE id=OLD.id; END;
--@statement
CREATE TRIGGER candidates_insert INSTEAD OF INSERT ON candidates WHEN NOT EXISTS(SELECT 1 FROM candidates WHERE id=NEW.id OR lut_hex=NEW.lut_hex) BEGIN
INSERT INTO closure_templates(digest,body) VALUES(randomblob(32),NEW.properties);
INSERT OR IGNORE INTO closure_candidates(id,lut_text,sigma,apn,degree,template_id,ortho,encoding,class_id,state) VALUES(NEW.id,NEW.lut_hex,NEW.sigma,NEW.apn,NEW.degree,last_insert_rowid(),X'',0,NEW.class_id,NEW.state); END;
--@statement
CREATE TABLE closure_comparisons(id INTEGER PRIMARY KEY,candidate_id TEXT NOT NULL REFERENCES closure_candidates(id),target_parent INTEGER NOT NULL REFERENCES parents(id),status TEXT NOT NULL,template_id INTEGER NOT NULL REFERENCES closure_templates(id),session_id INTEGER NOT NULL,encoding INTEGER NOT NULL CHECK(encoding IN (0,1)),v0 TEXT NOT NULL,v1 TEXT NOT NULL,v2 TEXT NOT NULL,v3 TEXT NOT NULL,v4 TEXT NOT NULL,v5 TEXT NOT NULL,v6 TEXT NOT NULL,v7 TEXT NOT NULL,v8 TEXT NOT NULL);
--@statement
CREATE INDEX comparisons_pair ON closure_comparisons(candidate_id,target_parent,id);
--@statement
CREATE VIEW comparisons AS SELECT e.id,e.candidate_id,e.target_parent,e.status,
(SELECT CASE WHEN e.encoding=0 THEN t.body ELSE replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(t.body,'!!vbf:v0!!',e.v0),'!!vbf:v1!!',e.v1),'!!vbf:v2!!',e.v2),'!!vbf:v3!!',e.v3),'!!vbf:v4!!',e.v4),'!!vbf:v5!!',e.v5),'!!vbf:v6!!',e.v6),'!!vbf:v7!!',e.v7),'!!vbf:v8!!',e.v8),'!!vbf:c:lut!!',(SELECT lut_hex FROM candidates WHERE id=e.candidate_id)),'!!vbf:t:lut!!',(SELECT c.lut_hex FROM parents p JOIN candidates c ON c.id=p.candidate_id WHERE p.id=e.target_parent)),'!!vbf:c:id!!',e.candidate_id),'!!vbf:t:id!!',(SELECT candidate_id FROM parents WHERE id=e.target_parent)) END FROM closure_templates t WHERE t.id=e.template_id) AS evidence,e.session_id FROM closure_comparisons e;
--@statement
CREATE TRIGGER comparisons_insert INSTEAD OF INSERT ON comparisons BEGIN
INSERT INTO closure_templates(digest,body) VALUES(randomblob(32),NEW.evidence);
INSERT INTO closure_comparisons(id,candidate_id,target_parent,status,template_id,session_id,encoding,v0,v1,v2,v3,v4,v5,v6,v7,v8) VALUES(NEW.id,NEW.candidate_id,NEW.target_parent,NEW.status,last_insert_rowid(),NEW.session_id,0,'','','','','','','','',''); END;
--@statement
CREATE TRIGGER comparisons_delete INSTEAD OF DELETE ON comparisons BEGIN DELETE FROM closure_comparisons WHERE id=OLD.id; END;
