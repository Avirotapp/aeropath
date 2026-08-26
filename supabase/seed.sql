insert into public.simulators(name,simulator_type,status) values
('C172-01','Cessna 172 G1000','AVAILABLE'),
('DA20-01','Diamond DA20 Analogue','AVAILABLE'),
('ATC-01','ATC Simulator','AVAILABLE'),
('VR-01','VR Simulator','AVAILABLE');

insert into public.courses(name,description) values
('Simulator Familiarisation','Core simulator orientation and operational familiarisation'),
('Procedures & Instrument Skills','Simulator procedures and instrument skills');

insert into public.system_modules(key,name,enabled) values
('sim_booking','Simulator Booking',true),('sim_hours','Simulator Hours',true),
('preflight','Pre-Flight Preparation',true),('documents','Documents',true),
('progress','Training Progress',true),('instructor_notes','Instructor Remarks',true),
('esms','Safety / ESMS',true),('hazards','Hazard Reporting',true),
('notifications','Notifications',true),('reports','Reports',true);

insert into public.safety_notices(title,body,severity) values
('Welcome to AeroPath','Operational safety notices will appear here.','INFO'),
('Simulator conduct','Follow instructor guidance and report simulator defects promptly.','INFO');
