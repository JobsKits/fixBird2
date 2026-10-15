INSERT IGNORE INTO repair_workers (id, display_name, service_areas, skills, status)
VALUES ('worker-demo', '林师傅', JSON_ARRAY('演示城区'), JSON_ARRAY('家电维修', '水电维修', '家电清洗'), 'approved');
