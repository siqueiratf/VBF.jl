function _closure_seed_progress(db)
    unfinished="j.parent_id=p.id AND j.kind IN ('prepare_v5','v5','switching') AND j.status!='done'"
    counts=Dict{String,Any}(only(_closure_rows(db,"SELECT COUNT(*) total,COALESCE(SUM(NOT EXISTS(SELECT 1 FROM jobs j WHERE $unfinished)),0) completed,COALESCE(SUM(NOT EXISTS(SELECT 1 FROM jobs j WHERE j.parent_id=p.id AND j.kind IN ('prepare_v5','v5') AND j.status!='done')),0) v5_completed,COALESCE(SUM(NOT EXISTS(SELECT 1 FROM jobs j WHERE j.parent_id=p.id AND j.kind='switching' AND j.status!='done')),0) switching_completed FROM parents p WHERE p.origin='root'")))
    roots=_closure_rows(db,"SELECT p.id,p.source,c.properties FROM parents p JOIN candidates c ON c.id=p.candidate_id WHERE p.origin='root' AND EXISTS(SELECT 1 FROM jobs j WHERE $unfinished) ORDER BY p.id LIMIT 1")
    counts["focus_available"]=!isempty(roots)
    isempty(roots) && return counts
    parent=only(roots)
    jobs=_closure_rows(db,"SELECT id,kind,status,direction,result FROM jobs WHERE parent_id=? AND kind IN ('prepare_v5','v5','switching') ORDER BY id",(parent["id"],))
    prepared=any(j->j["kind"]=="prepare_v5" && j["status"]=="done",jobs)
    spaces=filter(j->j["kind"]=="v5",jobs)
    proofs=[TOML.parse(j["result"]) for j in spaces]
    known=all(p->haskey(p,"total_x"),proofs)
    switching=filter(j->j["kind"]=="switching",jobs)
    focus=Dict{String,Any}("parent_id"=>parent["id"],"source"=>parent["source"],
        "root_index"=>get(TOML.parse(parent["properties"]),"root_index",parent["id"]),
        "prepared"=>prepared,"five_spaces_total"=>prepared ? length(spaces) : -1,
        "five_spaces_completed"=>count(j->j["status"]=="done",spaces),
        "cosets_checked"=>sum(max(0,Int(j["direction"])-1) for j in spaces;init=0),
        "cosets_total"=>prepared && known ? sum(Int(p["total_x"]) for p in proofs;init=0) : -1,
        "spaces_not_started"=>count(isempty,proofs),
        "switching_directions_checked"=>sum(clamp(Int(j["direction"])-1,0,255) for j in switching;init=0),
        "switching_directions_total"=>255*length(switching),
        "switching_complete"=>!isempty(switching) && all(j->j["status"]=="done",switching),
        "blocked_jobs"=>count(j->j["status"] in ("blocked","failed"),jobs))
    counts["focus"]=focus
    counts
end
