import React, { useEffect, useMemo, useState } from 'react';
import { createRoot } from 'react-dom/client';
import { createClient } from '@supabase/supabase-js';
import {
  AlertTriangle, CalendarDays, ChevronLeft, ChevronRight, Clock3, FileText,
  LayoutDashboard, LogOut, Plus, Plane, Settings, ShieldCheck, Users,
  BookOpen, X, Check, Ban, RefreshCw
} from 'lucide-react';
import './styles.css';

const supabase = createClient(
  import.meta.env.VITE_SUPABASE_URL || '',
  import.meta.env.VITE_SUPABASE_ANON_KEY || ''
);

const SIM_TYPES = {
  C172: 'Cessna 172 G1000',
  DA20: 'Diamond DA20 Analogue',
  ATC: 'ATC Simulator',
  VR: 'VR Simulator'
};

function App() {
  const [session, setSession] = useState(null);
  const [profile, setProfile] = useState(null);
  const [tab, setTab] = useState('dashboard');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => setSession(data.session));
    const { data } = supabase.auth.onAuthStateChange((_event, next) => setSession(next));
    return () => data.subscription.unsubscribe();
  }, []);

  useEffect(() => {
    if (!session) {
      setProfile(null);
      setLoading(false);
      return;
    }
    supabase.from('profiles').select('*').eq('id', session.user.id).single()
      .then(({ data }) => { setProfile(data); setLoading(false); });
  }, [session]);

  if (loading) return <div className="center">Loading AeroPath…</div>;
  if (!session) return <Auth />;
  return <Portal session={session} profile={profile} tab={tab} setTab={setTab} />;
}

function Auth() {
  const [mode, setMode] = useState('signin');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [name, setName] = useState('');
  const [msg, setMsg] = useState('');

  async function submit(e) {
    e.preventDefault();
    setMsg('');
    const result = mode === 'signin'
      ? await supabase.auth.signInWithPassword({ email, password })
      : await supabase.auth.signUp({ email, password, options: { data: { full_name: name } } });
    if (result.error) setMsg(result.error.message);
    else if (mode === 'signup') setMsg('Account created. Check your email if confirmation is enabled.');
  }

  return <div className="auth">
    <div className="brand">AEROPATH<span>OPS</span></div>
    <div className="auth-card">
      <div className="eyebrow">FLIGHT SIMULATION OPERATIONS</div>
      <h1>{mode === 'signin' ? 'Welcome back' : 'Create your AeroPath account'}</h1>
      <p className="muted">A lightweight operational portal for simulation teams.</p>
      <form onSubmit={submit}>
        {mode === 'signup' && <input placeholder="Full name" value={name} onChange={e => setName(e.target.value)} required />}
        <input type="email" placeholder="Email" value={email} onChange={e => setEmail(e.target.value)} required />
        <input type="password" placeholder="Password" value={password} onChange={e => setPassword(e.target.value)} required />
        <button className="primary">{mode === 'signin' ? 'Sign in' : 'Create account'}</button>
      </form>
      {msg && <div className="notice">{msg}</div>}
      <button className="link" onClick={() => setMode(mode === 'signin' ? 'signup' : 'signin')}>
        {mode === 'signin' ? 'Need an account? Create one' : 'Already have an account? Sign in'}
      </button>
    </div>
  </div>;
}

function Portal({ session, profile, tab, setTab }) {
  const role = profile?.role || 'STUDENT';
  const nav = role === 'STUDENT'
    ? ['dashboard', 'bookings', 'progress', 'documents', 'safety']
    : role === 'INSTRUCTOR'
      ? ['dashboard', 'bookings', 'students', 'progress', 'safety']
      : role === 'SAFETY_MANAGER'
        ? ['dashboard', 'safety', 'reports']
        : ['dashboard', 'simulators', 'bookings', 'users', 'modules', 'audit'];

  const titles = {
    dashboard: 'Virtual Cockpit', bookings: 'Simulator Scheduler', progress: 'Training Progress',
    documents: 'Documents', safety: 'Safety Control Tower', students: 'Students',
    simulators: 'Simulator Inventory', users: 'User Management', modules: 'System Modules',
    audit: 'Audit Activity', reports: 'Safety Reports'
  };

  const pages = {
    dashboard: <Dashboard profile={profile} setTab={setTab} />,
    bookings: <Bookings profile={profile} />,
    progress: <Progress profile={profile} />,
    documents: <Documents profile={profile} />,
    safety: <Safety />,
    reports: <Safety />,
    simulators: <Simulators />,
    modules: <Modules />,
    audit: <Audit />,
    students: <Students />,
    users: <Students />
  };

  return <div className="app">
    <aside>
      <div className="logo">AEROPATH<span>OPS</span></div>
      <div className="role">{role.replace('_', ' ')}</div>
      {nav.map(n => <button key={n} className={tab === n ? 'nav active' : 'nav'} onClick={() => setTab(n)}>
        {icon(n)}<span>{titles[n]}</span>
      </button>)}
      <div className="side-bottom">
        <button className="nav" onClick={() => supabase.auth.signOut()}><LogOut /><span>Sign out</span></button>
      </div>
    </aside>
    <main>
      <header>
        <div><div className="eyebrow">AEROPATH OPERATIONS</div><h2>{titles[tab]}</h2></div>
        <div className="user">{profile?.full_name || session.user.email}</div>
      </header>
      <section className="content">{pages[tab] || <Empty title={titles[tab]} />}</section>
    </main>
  </div>;
}

function icon(n) {
  const C = { dashboard: LayoutDashboard, bookings: CalendarDays, progress: BookOpen, documents: FileText,
    safety: ShieldCheck, students: Users, simulators: Plane, users: Users, modules: Settings,
    audit: Clock3, reports: AlertTriangle }[n] || ChevronRight;
  return <C size={18} />;
}

function Dashboard({ profile, setTab }) {
  const [next, setNext] = useState(null);
  useEffect(() => {
    if (!profile) return;
    supabase.from('bookings').select('*,simulators(name,simulator_type)')
      .eq('student_id', profile.id).in('status', ['REQUESTED', 'CONFIRMED'])
      .gte('starts_at', new Date().toISOString()).order('starts_at').limit(1)
      .then(({ data }) => setNext(data?.[0] || null));
  }, [profile]);

  return <>
    <div className="hero">
      <div><div className="eyebrow">OPERATIONAL STATUS</div><h1>Good to see you, {profile?.full_name?.split(' ')[0] || 'pilot'}.</h1>
        <p>Manage simulator sessions, preparation and training activity from one cockpit.</p></div>
      <Plane size={72} />
    </div>
    <div className="grid four">
      <Card icon={<Clock3 />} label="Total simulator hours" value={`${Number(profile?.total_sim_hours || 0).toFixed(1)} h`} />
      <Card icon={<CalendarDays />} label="Next session" value={next ? formatDate(next.starts_at) : 'No session'} />
      <Card icon={<FileText />} label="Preparation" value="Not started" />
      <Card icon={<ShieldCheck />} label="Safety notices" value="2 active" />
    </div>
    <div className="grid two">
      <Panel title="Simulator fleet"><Fleet /></Panel>
      <Panel title="Quick actions"><div className="actions">
        <Action t="Book simulator" onClick={() => setTab('bookings')} />
        <Action t="Open pre-flight preparation" />
        <Action t="View documents" onClick={() => setTab('documents')} />
        <Action t="View progress" onClick={() => setTab('progress')} />
      </div></Panel>
    </div>
  </>;
}

function Card({ icon: item, label, value }) {
  return <div className="card"><div className="cardicon">{item}</div><div className="muted">{label}</div><strong>{value}</strong></div>;
}
function Panel({ title, children }) { return <div className="panel"><div className="panel-title"><h3>{title}</h3></div>{children}</div>; }
function Action({ t, onClick }) { return <button className="action" onClick={onClick}>{t}<ChevronRight size={17} /></button>; }

function Fleet() {
  const [data, setData] = useState([]);
  useEffect(() => { supabase.from('simulators').select('*').order('name').then(({ data }) => setData(data || [])); }, []);
  return <div className="fleet">{data.map(s => <div className="row" key={s.id}><Plane size={20} /><div><b>{s.name}</b><small>{s.simulator_type}</small></div><span className={`status ${s.status.toLowerCase()}`}>{s.status}</span></div>)}</div>;
}

function Bookings({ profile }) {
  const [data, setData] = useState([]);
  const [sims, setSims] = useState([]);
  const [filter, setFilter] = useState('ALL');
  const [selectedSim, setSelectedSim] = useState('ALL');
  const [weekStart, setWeekStart] = useState(startOfWeek(new Date()));
  const [open, setOpen] = useState(false);
  const [notice, setNotice] = useState('');
  const [form, setForm] = useState({ simulator_id: '', date: toDateInput(new Date()), time: '09:00', duration: '60', notes: '' });
  const isStaff = ['INSTRUCTOR', 'ADMINISTRATOR'].includes(profile?.role);

  async function load() {
    let q = supabase.from('bookings').select('*,simulators(name,simulator_type),student:student_id(full_name,email)').order('starts_at');
    if (profile?.role === 'STUDENT') q = q.eq('student_id', profile.id);
    const [bookingResult, simResult] = await Promise.all([
      q,
      supabase.from('simulators').select('*').eq('status', 'AVAILABLE').order('name')
    ]);
    setData(bookingResult.data || []);
    setSims(simResult.data || []);
  }
  useEffect(() => { if (profile) load(); }, [profile]);

  const visible = useMemo(() => {
    return data.filter(b => filter === 'ALL' || b.status === filter)
      .filter(b => selectedSim === 'ALL' || b.simulator_id === selectedSim);
  }, [data, filter, selectedSim]);

  async function createBooking(e) {
    e.preventDefault(); setNotice('');
    const start = new Date(`${form.date}T${form.time}`);
    const end = new Date(start.getTime() + Number(form.duration) * 60000);
    if (start <= new Date()) { setNotice('Choose a future start time.'); return; }
    if (!form.simulator_id) { setNotice('Select a simulator.'); return; }
    const { error } = await supabase.from('bookings').insert({
      simulator_id: form.simulator_id, student_id: profile.id,
      starts_at: start.toISOString(), ends_at: end.toISOString(),
      notes: form.notes || null, status: 'REQUESTED'
    });
    if (error) setNotice(error.message.includes('already booked') ? 'That simulator is already booked during this time. Choose another slot.' : error.message);
    else { setNotice('Booking request submitted.'); setOpen(false); await load(); }
  }

  async function updateStatus(id, status) {
    setNotice('');
    const { error } = await supabase.from('bookings').update({ status }).eq('id', id);
    if (error) setNotice(error.message); else await load();
  }

  async function cancelStudentBooking(id) {
    await updateStatus(id, 'CANCELLED');
  }

  const weekDays = Array.from({ length: 7 }, (_, i) => addDays(weekStart, i));
  const hours = Array.from({ length: 12 }, (_, i) => i + 8); // 08:00-19:00

  return <>
    <div className="scheduler-head">
      <div><div className="muted">Simulator operations</div><h3>Scheduler</h3><p className="muted">Request a slot, see conflicts, and track your simulator sessions.</p></div>
      <div className="head-actions">
        <button className="secondary" onClick={() => { setWeekStart(startOfWeek(new Date())); load(); }}><RefreshCw size={16} /> Today</button>
        {profile?.role === 'STUDENT' && <button className="primary small" onClick={() => setOpen(true)}><Plus size={16} /> Request booking</button>}
      </div>
    </div>

    {notice && <div className="notice inline-notice">{notice}</div>}

    {open && <BookingModal sims={sims} form={form} setForm={setForm} onSubmit={createBooking} onClose={() => setOpen(false)} />}

    <div className="scheduler-controls panel">
      <div className="date-nav"><button className="icon-btn" onClick={() => setWeekStart(addDays(weekStart, -7))}><ChevronLeft /></button>
        <strong>{formatRange(weekStart, addDays(weekStart, 6))}</strong>
        <button className="icon-btn" onClick={() => setWeekStart(addDays(weekStart, 7))}><ChevronRight /></button></div>
      <select value={selectedSim} onChange={e => setSelectedSim(e.target.value)}><option value="ALL">All simulators</option>{sims.map(s => <option key={s.id} value={s.id}>{s.name} — {s.simulator_type}</option>)}</select>
      <select value={filter} onChange={e => setFilter(e.target.value)}><option value="ALL">All statuses</option><option value="REQUESTED">Requested</option><option value="CONFIRMED">Confirmed</option><option value="CANCELLED">Cancelled</option><option value="COMPLETED">Completed</option></select>
    </div>

    <div className="calendar panel">
      <div className="calendar-grid calendar-header">
        <div className="time-label"></div>
        {weekDays.map(day => <div className={`day-head ${sameDay(day, new Date()) ? 'today' : ''}`} key={day.toISOString()}><small>{day.toLocaleDateString([], { weekday: 'short' })}</small><strong>{day.getDate()}</strong></div>)}
      </div>
      <div className="calendar-body">
        {hours.map(hour => <div className="calendar-row" key={hour}>
          <div className="time-label">{String(hour).padStart(2, '0')}:00</div>
          {weekDays.map(day => <div className="slot-cell" key={`${day.toISOString()}-${hour}`}>
            {visible.filter(b => sameDay(new Date(b.starts_at), day) && new Date(b.starts_at).getHours() === hour).map(b => <BookingBlock key={b.id} booking={b} isStaff={isStaff} canCancel={profile?.role === 'STUDENT' && b.student_id === profile.id} onStatus={updateStatus} onCancel={cancelStudentBooking} />)}
          </div>)}
        </div>)}
      </div>
    </div>

    <div className="panel booking-list">
      <div className="panel-title"><h3>{isStaff ? 'All booking requests' : 'My bookings'}</h3><span>{visible.length} shown</span></div>
      {!visible.length ? <Empty title="No bookings match this view" text="Try another simulator, status or week." /> :
        <table><thead><tr><th>Date / Time</th><th>Simulator</th>{isStaff && <th>Student</th>}<th>Duration</th><th>Status</th><th></th></tr></thead>
          <tbody>{visible.map(b => <tr key={b.id}><td>{formatDate(b.starts_at)}<small>{formatTime(b.starts_at)}–{formatTime(b.ends_at)}</small></td><td><b>{b.simulators?.name}</b><small>{b.simulators?.simulator_type}</small></td>{isStaff && <td>{b.student?.full_name || b.student?.email || 'Student'}</td>}<td>{durationMinutes(b.starts_at,b.ends_at)} min</td><td><span className={`pill ${b.status.toLowerCase()}`}>{b.status}</span></td><td className="row-actions">{isStaff && b.status === 'REQUESTED' && <><button title="Confirm" className="mini success" onClick={() => updateStatus(b.id,'CONFIRMED')}><Check size={14}/></button><button title="Reject" className="mini danger" onClick={() => updateStatus(b.id,'CANCELLED')}><Ban size={14}/></button></>}{profile?.role === 'STUDENT' && ['REQUESTED','CONFIRMED'].includes(b.status) && <button title="Cancel" className="mini danger" onClick={() => cancelStudentBooking(b.id)}><X size={14}/></button>}</td></tr>)}</tbody></table>}
    </div>
  </>;
}

function BookingModal({ sims, form, setForm, onSubmit, onClose }) {
  return <div className="modal-backdrop"><div className="modal panel"><div className="modal-head"><div><div className="eyebrow">NEW SIMULATOR REQUEST</div><h3>Book a simulator</h3></div><button className="icon-btn" onClick={onClose}><X /></button></div>
    <form className="formgrid" onSubmit={onSubmit}>
      <label>Simulator<select value={form.simulator_id} onChange={e=>setForm({...form,simulator_id:e.target.value})} required><option value="">Select simulator</option>{sims.map(s=><option key={s.id} value={s.id}>{s.name} — {s.simulator_type}</option>)}</select></label>
      <label>Date<input type="date" value={form.date} min={toDateInput(new Date())} onChange={e=>setForm({...form,date:e.target.value})} required /></label>
      <label>Start time<select value={form.time} onChange={e=>setForm({...form,time:e.target.value})}>{timeOptions().map(t=><option key={t}>{t}</option>)}</select></label>
      <label>Duration<select value={form.duration} onChange={e=>setForm({...form,duration:e.target.value})}><option value="30">30 minutes</option><option value="60">60 minutes</option><option value="90">90 minutes</option><option value="120">120 minutes</option><option value="180">180 minutes</option></select></label>
      <label className="full">Notes<input placeholder="Lesson, instructor or preparation notes (optional)" value={form.notes} onChange={e=>setForm({...form,notes:e.target.value})}/></label>
      <div className="modal-actions"><button type="button" className="secondary" onClick={onClose}>Cancel</button><button className="primary">Submit request</button></div>
    </form>
  </div></div>;
}

function BookingBlock({ booking, isStaff, canCancel, onStatus, onCancel }) {
  return <div className={`booking-block ${booking.status.toLowerCase()}`} title={`${booking.simulators?.name} ${formatTime(booking.starts_at)}–${formatTime(booking.ends_at)}`}>
    <b>{booking.simulators?.name}</b><span>{formatTime(booking.starts_at)}–{formatTime(booking.ends_at)}</span><em>{booking.status}</em>
    <div className="block-actions">{isStaff && booking.status === 'REQUESTED' && <><button onClick={() => onStatus(booking.id,'CONFIRMED')}><Check size={12}/></button><button onClick={() => onStatus(booking.id,'CANCELLED')}><Ban size={12}/></button></>}{canCancel && ['REQUESTED','CONFIRMED'].includes(booking.status) && <button onClick={() => onCancel(booking.id)}><X size={12}/></button>}</div>
  </div>;
}

function Progress({ profile }) {
  const [rows,setRows]=useState([]);
  useEffect(()=>{if(profile)supabase.from('student_progress').select('*,lessons(name,courses(name))').eq('student_id',profile.id).then(({data})=>setRows(data||[]));},[profile]);
  return <div className="panel"><h3>Training progress</h3><p className="muted">Lesson and course progress recorded for your account.</p>{rows.map(r=><div className="row" key={r.id}><BookOpen size={20}/><div><b>{r.lessons?.name}</b><small>{r.lessons?.courses?.name}</small></div><span className="pill">{r.status}</span></div>)}{!rows.length&&<Empty title="No progress recorded yet"/>}</div>;
}
function Documents({ profile }) {
  const [rows,setRows]=useState([]);
  useEffect(()=>{if(profile)supabase.from('documents').select('*').eq('owner_id',profile.id).order('created_at',{ascending:false}).then(({data})=>setRows(data||[]));},[profile]);
  return <div className="panel"><h3>Your documents</h3><p className="muted">Document management is connected to the database; advanced upload UI is a later module.</p>{rows.map(d=><div className="row" key={d.id}><FileText/><div><b>{d.title}</b><small>{d.category||'Document'}</small></div></div>)}{!rows.length&&<Empty title="No documents yet"/>}</div>;
}
function Safety(){const [rows,setRows]=useState([]);useEffect(()=>{supabase.from('safety_notices').select('*').eq('published',true).order('created_at',{ascending:false}).then(({data})=>setRows(data||[]));},[]);return <div className="grid two">{rows.map(n=><div className="notice-card" key={n.id}><span className="pill">{n.severity}</span><h3>{n.title}</h3><p>{n.body}</p></div>)}{!rows.length&&<Empty title="No active safety notices"/>}</div>}
function Simulators(){return <div className="panel"><h3>Simulator inventory</h3><Fleet/></div>}
function Modules(){const [rows,setRows]=useState([]);useEffect(()=>{supabase.from('system_modules').select('*').order('name').then(({data})=>setRows(data||[]));},[]);return <div className="panel"><h3>System modules</h3>{rows.map(r=><div className="row" key={r.key}><Settings/><div><b>{r.name}</b><small>{r.key}</small></div><span className="pill">{r.enabled?'ENABLED':'DISABLED'}</span></div>)}</div>}
function Audit(){const [rows,setRows]=useState([]);useEffect(()=>{supabase.from('audit_logs').select('*').order('created_at',{ascending:false}).limit(50).then(({data})=>setRows(data||[]));},[]);return <div className="panel"><h3>Recent audit activity</h3>{rows.map(r=><div className="row" key={r.id}><Clock3/><div><b>{r.action}</b><small>{r.entity_type||'System'} · {formatDate(r.created_at)}</small></div></div>)}{!rows.length&&<Empty title="No audit activity yet"/>}</div>}
function Students(){return <div className="panel"><h3>Students</h3><p className="muted">Student management is the next operational module.</p><Empty title="No staff workflow configured yet"/></div>}
function Empty({title,text}){return <div className="empty"><div className="cardicon"><CalendarDays/></div><h3>{title}</h3>{text&&<p className="muted">{text}</p>}</div>}

function startOfWeek(date){const d=new Date(date);const day=d.getDay();const diff=day===0?-6:1-day;d.setHours(0,0,0,0);d.setDate(d.getDate()+diff);return d;}
function addDays(date,n){const d=new Date(date);d.setDate(d.getDate()+n);return d;}
function sameDay(a,b){return a.getFullYear()===b.getFullYear()&&a.getMonth()===b.getMonth()&&a.getDate()===b.getDate();}
function toDateInput(date){const d=new Date(date);return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;}
function timeOptions(){return Array.from({length:24},(_,i)=>i).flatMap(h=>[0,30].map(m=>`${String(h).padStart(2,'0')}:${String(m).padStart(2,'0')}`)).filter(t=>t>='06:00'&&t<='22:00');}
function formatDate(value){return new Date(value).toLocaleDateString([], {day:'2-digit',month:'short',year:'numeric'});}
function formatTime(value){return new Date(value).toLocaleTimeString([], {hour:'2-digit',minute:'2-digit'});}
function formatRange(a,b){return `${a.toLocaleDateString([], {day:'2-digit',month:'short'})} – ${b.toLocaleDateString([], {day:'2-digit',month:'short',year:'numeric'})}`;}
function durationMinutes(a,b){return Math.round((new Date(b)-new Date(a))/60000);}

createRoot(document.getElementById('root')).render(<App />);
