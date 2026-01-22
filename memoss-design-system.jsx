import React, { useState } from 'react';

// ============================================
// MEMOSS DESIGN SYSTEM
// "your reminder" — A friendly, nature-inspired reminder app
// ============================================

const tokens = {
  colors: {
    primary: {
      50: '#F0F9F4',
      100: '#DCFCE7',
      200: '#BBF7D0',
      300: '#86EFAC',
      400: '#4ADE80',
      500: '#22C55E',
      600: '#16A34A',
      700: '#15803D',
      800: '#166534',
      900: '#14532D',
    },
    secondary: {
      50: '#F6F9F6',
      100: '#E8F0E8',
      200: '#D1E2D1',
      300: '#AECBAE',
      400: '#86B086',
      500: '#6B9B6B',
      600: '#567D56',
      700: '#456445',
    },
    accent: {
      50: '#FEFCF3',
      100: '#FEF9E7',
      200: '#FEF3C7',
      300: '#FDE68A',
      400: '#FACC15',
      500: '#EAB308',
      600: '#CA8A04',
    },
    pink: {
      100: '#FFE4E6',
      400: '#FB7185',
      500: '#F43F5E',
    },
    neutral: {
      0: '#FFFFFF',
      50: '#FDFCFA',
      100: '#F9F7F3',
      200: '#F3F0EA',
      300: '#E8E4DC',
      400: '#D4CEC4',
      500: '#A8A298',
      600: '#7D786F',
      700: '#5C5852',
      800: '#3D3A36',
      900: '#252320',
      950: '#1A1816',
    },
    success: '#22C55E',
    warning: '#EAB308',
    error: '#F43F5E',
  },
  typography: {
    fontFamily: {
      display: '"Nunito", system-ui, sans-serif',
      body: '"Nunito Sans", system-ui, sans-serif',
    },
    fontSize: {
      xs: '0.75rem',
      sm: '0.875rem',
      base: '1rem',
      lg: '1.125rem',
      xl: '1.25rem',
      '2xl': '1.5rem',
      '3xl': '1.875rem',
      '4xl': '2.25rem',
    },
    fontWeight: {
      normal: 400,
      medium: 500,
      semibold: 600,
      bold: 700,
      extrabold: 800,
    },
  },
  spacing: {
    1: '0.25rem', 2: '0.5rem', 3: '0.75rem', 4: '1rem',
    5: '1.25rem', 6: '1.5rem', 8: '2rem', 10: '2.5rem', 12: '3rem',
  },
  borderRadius: {
    sm: '0.5rem', md: '0.75rem', lg: '1rem', xl: '1.5rem', '2xl': '2rem', full: '9999px',
  },
  shadows: {
    sm: '0 1px 3px rgba(20, 83, 45, 0.06)',
    md: '0 4px 12px rgba(20, 83, 45, 0.08)',
    lg: '0 8px 24px rgba(20, 83, 45, 0.1)',
    xl: '0 16px 48px rgba(20, 83, 45, 0.12)',
  },
  transitions: {
    fast: '150ms ease',
    normal: '250ms ease',
    bounce: '500ms cubic-bezier(0.34, 1.56, 0.64, 1)',
  },
};

const baseStyles = `
  @import url('https://fonts.googleapis.com/css2?family=Nunito:wght@400;500;600;700;800&family=Nunito+Sans:wght@400;500;600;700&display=swap');
  * { box-sizing: border-box; margin: 0; padding: 0; }
`;

// Moss Mascot Component
const MossMascot = ({ size = 120, mood = 'happy', animate = false }) => {
  const moods = {
    happy: { eyeScale: 1, mouthOpen: true },
    excited: { eyeScale: 1.1, mouthOpen: true },
    calm: { eyeScale: 0.9, mouthOpen: false },
    sleepy: { eyeScale: 0.6, mouthOpen: false },
  };
  const { eyeScale, mouthOpen } = moods[mood];
  
  return (
    <svg width={size} height={size * 0.7} viewBox="0 0 200 140" fill="none">
      <defs>
        <radialGradient id="mossGrad" cx="50%" cy="30%" r="70%">
          <stop offset="0%" stopColor="#86EFAC" />
          <stop offset="50%" stopColor="#4ADE80" />
          <stop offset="100%" stopColor="#16A34A" />
        </radialGradient>
      </defs>
      <ellipse cx="100" cy="130" rx="70" ry="8" fill="#16A34A" opacity="0.15"/>
      <ellipse cx="100" cy="90" rx="85" ry="50" fill="url(#mossGrad)" 
        style={animate ? { animation: 'mossWiggle 3s ease-in-out infinite' } : {}} />
      {[...Array(12)].map((_, i) => (
        <circle key={i} cx={35 + (i % 6) * 26} cy={70 + Math.floor(i / 6) * 30 + (i % 2) * 10}
          r={8 + (i % 3) * 3} fill={i % 2 === 0 ? '#86EFAC' : '#4ADE80'} opacity="0.6" />
      ))}
      {[40, 70, 100, 130, 160].map((x, i) => (
        <g key={i} transform={`translate(${x}, ${35 + (i % 2) * 8})`}>
          <path d={`M0,20 Q${-3 + i},10 0,0 Q${3 - i},10 0,20`} fill="#4ADE80"
            style={animate ? { animation: `sproutSway ${1.5 + i * 0.2}s ease-in-out infinite`, transformOrigin: '0 20px' } : {}} />
          {i !== 2 && (<><ellipse cx="-4" cy="5" rx="3" ry="4" fill="#22C55E"/><ellipse cx="4" cy="5" rx="3" ry="4" fill="#22C55E"/></>)}
        </g>
      ))}
      {[[25, 45], [175, 50], [50, 25], [150, 30]].map(([x, y], i) => (
        <g key={i} style={animate ? { animation: `sparkle ${1 + i * 0.3}s ease-in-out infinite` } : {}}>
          <path d={`M${x},${y} l2,-6 l2,6 l-6,-2 l6,0 l-6,2 l6,0 l-2,-6`} fill="#FDE68A" opacity="0.8" />
        </g>
      ))}
      <g transform={`translate(70, 80) scale(${eyeScale})`}>
        <ellipse cx="0" cy="0" rx="12" ry="14" fill="#1a1a1a"/>
        <ellipse cx="3" cy="-4" rx="4" ry="5" fill="white"/>
      </g>
      <g transform={`translate(130, 80) scale(${eyeScale})`}>
        <ellipse cx="0" cy="0" rx="12" ry="14" fill="#1a1a1a"/>
        <ellipse cx="3" cy="-4" rx="4" ry="5" fill="white"/>
      </g>
      {mouthOpen ? (
        <><path d="M90,100 Q100,115 110,100" fill="#1a1a1a"/><ellipse cx="100" cy="106" rx="6" ry="4" fill="#FB7185"/></>
      ) : (
        <path d="M90,102 Q100,108 110,102" stroke="#1a1a1a" strokeWidth="3" strokeLinecap="round" fill="none" />
      )}
      <style>{`
        @keyframes mossWiggle { 0%, 100% { transform: scaleX(1); } 50% { transform: scaleX(1.02); } }
        @keyframes sproutSway { 0%, 100% { transform: rotate(-3deg); } 50% { transform: rotate(3deg); } }
        @keyframes sparkle { 0%, 100% { opacity: 0.4; transform: scale(0.8); } 50% { opacity: 1; transform: scale(1.2); } }
      `}</style>
    </svg>
  );
};

// Button Component
const Button = ({ children, variant = 'primary', size = 'md', icon, iconOnly = false, fullWidth = false, onClick, style = {} }) => {
  const baseStyle = {
    fontFamily: tokens.typography.fontFamily.display, fontWeight: tokens.typography.fontWeight.bold,
    borderRadius: iconOnly ? tokens.borderRadius.full : tokens.borderRadius.xl, border: 'none', cursor: 'pointer',
    display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: tokens.spacing[2],
    transition: `all ${tokens.transitions.normal}`, width: fullWidth ? '100%' : 'auto',
  };
  const sizes = {
    sm: { padding: iconOnly ? tokens.spacing[2] : `${tokens.spacing[2]} ${tokens.spacing[4]}`, fontSize: tokens.typography.fontSize.sm, minHeight: '40px', minWidth: iconOnly ? '40px' : 'auto' },
    md: { padding: iconOnly ? tokens.spacing[3] : `${tokens.spacing[3]} ${tokens.spacing[6]}`, fontSize: tokens.typography.fontSize.base, minHeight: '52px', minWidth: iconOnly ? '52px' : 'auto' },
    lg: { padding: iconOnly ? tokens.spacing[4] : `${tokens.spacing[4]} ${tokens.spacing[8]}`, fontSize: tokens.typography.fontSize.lg, minHeight: '60px', minWidth: iconOnly ? '60px' : 'auto' },
  };
  const variants = {
    primary: { background: tokens.colors.primary[500], color: tokens.colors.neutral[0], boxShadow: tokens.shadows.md },
    secondary: { background: tokens.colors.neutral[0], color: tokens.colors.neutral[800], border: `2px solid ${tokens.colors.neutral[200]}` },
    ghost: { background: 'transparent', color: tokens.colors.neutral[700] },
    soft: { background: tokens.colors.primary[100], color: tokens.colors.primary[700] },
    accent: { background: tokens.colors.accent[500], color: tokens.colors.neutral[900] },
  };
  return (
    <button onClick={onClick} style={{ ...baseStyle, ...sizes[size], ...variants[variant], ...style }}>
      {icon && <span style={{ display: 'flex', alignItems: 'center' }}>{icon}</span>}
      {!iconOnly && children}
    </button>
  );
};

// Input Component
const Input = ({ label, placeholder, value, onChange, icon, style = {} }) => (
  <div style={{ width: '100%', ...style }}>
    {label && <label style={{ display: 'block', fontFamily: tokens.typography.fontFamily.display, fontSize: tokens.typography.fontSize.sm, fontWeight: tokens.typography.fontWeight.semibold, color: tokens.colors.neutral[700], marginBottom: tokens.spacing[2] }}>{label}</label>}
    <div style={{ position: 'relative' }}>
      {icon && <span style={{ position: 'absolute', left: tokens.spacing[4], top: '50%', transform: 'translateY(-50%)', color: tokens.colors.neutral[400], display: 'flex' }}>{icon}</span>}
      <input type="text" placeholder={placeholder} value={value} onChange={onChange}
        style={{ width: '100%', padding: `${tokens.spacing[4]} ${icon ? tokens.spacing[12] : tokens.spacing[4]}`, fontFamily: tokens.typography.fontFamily.body, fontSize: tokens.typography.fontSize.base, color: tokens.colors.neutral[800], background: tokens.colors.neutral[0], border: `2px solid ${tokens.colors.neutral[200]}`, borderRadius: tokens.borderRadius.xl, outline: 'none' }} />
    </div>
  </div>
);

// Card Component
const Card = ({ children, variant = 'elevated', padding = 'md', style = {} }) => {
  const paddings = { sm: tokens.spacing[3], md: tokens.spacing[5], lg: tokens.spacing[6] };
  const variants = {
    elevated: { background: tokens.colors.neutral[0], boxShadow: tokens.shadows.lg, border: `1px solid ${tokens.colors.neutral[100]}` },
    outlined: { background: tokens.colors.neutral[0], border: `2px solid ${tokens.colors.neutral[200]}` },
    soft: { background: tokens.colors.primary[50], border: `1px solid ${tokens.colors.primary[100]}` },
    nature: { background: `linear-gradient(135deg, ${tokens.colors.primary[50]} 0%, ${tokens.colors.neutral[50]} 100%)`, border: `1px solid ${tokens.colors.primary[100]}` },
  };
  return <div style={{ borderRadius: tokens.borderRadius['2xl'], padding: paddings[padding], ...variants[variant], ...style }}>{children}</div>;
};

// Checkbox Component
const Checkbox = ({ checked, onChange, label, strikethrough = false }) => (
  <label style={{ display: 'flex', alignItems: 'flex-start', gap: tokens.spacing[3], cursor: 'pointer' }}>
    <div onClick={onChange} style={{ width: '26px', height: '26px', borderRadius: tokens.borderRadius.md, border: `2px solid ${checked ? tokens.colors.primary[500] : tokens.colors.neutral[300]}`, background: checked ? tokens.colors.primary[500] : tokens.colors.neutral[0], display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
      {checked && <svg width="14" height="14" viewBox="0 0 14 14" fill="none"><path d="M2 7L5.5 10.5L12 3" stroke="white" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"/></svg>}
    </div>
    <span style={{ fontSize: tokens.typography.fontSize.base, color: checked ? tokens.colors.neutral[400] : tokens.colors.neutral[800], textDecoration: strikethrough && checked ? 'line-through' : 'none', lineHeight: 1.5 }}>{label}</span>
  </label>
);

// Badge Component
const Badge = ({ children, variant = 'default' }) => {
  const variants = {
    default: { background: tokens.colors.neutral[200], color: tokens.colors.neutral[700] },
    primary: { background: tokens.colors.primary[100], color: tokens.colors.primary[700] },
    secondary: { background: tokens.colors.secondary[100], color: tokens.colors.secondary[700] },
    accent: { background: tokens.colors.accent[100], color: tokens.colors.accent[600] },
    pink: { background: tokens.colors.pink[100], color: tokens.colors.pink[500] },
  };
  return <span style={{ display: 'inline-flex', alignItems: 'center', borderRadius: tokens.borderRadius.full, fontFamily: tokens.typography.fontFamily.display, fontWeight: tokens.typography.fontWeight.bold, padding: `${tokens.spacing[1]} ${tokens.spacing[3]}`, fontSize: tokens.typography.fontSize.xs, ...variants[variant] }}>{children}</span>;
};

// Date Pill Component
const DatePill = ({ day, weekday, isActive = false, hasReminder = false }) => (
  <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', padding: `${tokens.spacing[3]} ${tokens.spacing[4]}`, borderRadius: tokens.borderRadius.xl, background: isActive ? tokens.colors.primary[500] : 'transparent', color: isActive ? tokens.colors.neutral[0] : tokens.colors.neutral[600], cursor: 'pointer', minWidth: '56px', position: 'relative' }}>
    <span style={{ fontSize: tokens.typography.fontSize.xl, fontWeight: tokens.typography.fontWeight.extrabold, fontFamily: tokens.typography.fontFamily.display, lineHeight: 1.2 }}>{day}</span>
    <span style={{ fontSize: tokens.typography.fontSize.xs, fontWeight: tokens.typography.fontWeight.semibold, textTransform: 'uppercase', letterSpacing: '0.5px', marginTop: '2px', opacity: 0.8 }}>{weekday}</span>
    {hasReminder && !isActive && <div style={{ position: 'absolute', bottom: '8px', width: '6px', height: '6px', borderRadius: '50%', background: tokens.colors.primary[400] }} />}
  </div>
);

// Reminder Card Component
const ReminderCard = ({ title, time, recurrence, completed = false, onToggle, tags = [], priority }) => (
  <Card variant="elevated" padding="md" style={{ marginBottom: tokens.spacing[3] }}>
    <div style={{ display: 'flex', alignItems: 'flex-start', gap: tokens.spacing[4] }}>
      <Checkbox checked={completed} onChange={onToggle} strikethrough label="" />
      <div style={{ flex: 1 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: tokens.spacing[2], marginBottom: tokens.spacing[1] }}>
          <h4 style={{ fontFamily: tokens.typography.fontFamily.display, fontSize: tokens.typography.fontSize.base, fontWeight: tokens.typography.fontWeight.semibold, color: completed ? tokens.colors.neutral[400] : tokens.colors.neutral[800], textDecoration: completed ? 'line-through' : 'none', margin: 0 }}>{title}</h4>
          {priority === 'high' && <Badge variant="pink">!</Badge>}
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: tokens.spacing[3], flexWrap: 'wrap' }}>
          {time && <span style={{ display: 'flex', alignItems: 'center', gap: tokens.spacing[1], fontSize: tokens.typography.fontSize.sm, color: tokens.colors.neutral[500] }}><ClockIcon size={14} />{time}</span>}
          {recurrence && <span style={{ display: 'flex', alignItems: 'center', gap: tokens.spacing[1], fontSize: tokens.typography.fontSize.sm, color: tokens.colors.secondary[500] }}><RepeatIcon size={14} />{recurrence}</span>}
        </div>
        {tags.length > 0 && <div style={{ display: 'flex', gap: tokens.spacing[2], marginTop: tokens.spacing[2] }}>{tags.map((tag, i) => <Badge key={i} variant="primary">{tag}</Badge>)}</div>}
      </div>
    </div>
  </Card>
);

// FAB Component
const FAB = ({ icon, onClick }) => (
  <button onClick={onClick} style={{ width: '68px', height: '68px', borderRadius: tokens.borderRadius.full, border: 'none', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: tokens.shadows.xl, background: tokens.colors.primary[500], color: tokens.colors.neutral[0] }}>{icon}</button>
);

// Icons
const PlusIcon = ({ size = 24, color = 'currentColor' }) => (<svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2.5" strokeLinecap="round"><line x1="12" y1="5" x2="12" y2="19" /><line x1="5" y1="12" x2="19" y2="12" /></svg>);
const ClockIcon = ({ size = 24, color = 'currentColor' }) => (<svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2" strokeLinecap="round"><circle cx="12" cy="12" r="9" /><polyline points="12,7 12,12 15,14" /></svg>);
const RepeatIcon = ({ size = 24, color = 'currentColor' }) => (<svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2" strokeLinecap="round"><path d="M17 2l4 4-4 4" /><path d="M3 11V9a4 4 0 014-4h14" /><path d="M7 22l-4-4 4-4" /><path d="M21 13v2a4 4 0 01-4 4H3" /></svg>);
const BellIcon = ({ size = 24, color = 'currentColor' }) => (<svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2" strokeLinecap="round"><path d="M18 8A6 6 0 006 8c0 7-3 9-3 9h18s-3-2-3-9" /><path d="M13.73 21a2 2 0 01-3.46 0" /></svg>);
const CheckIcon = ({ size = 24, color = 'currentColor' }) => (<svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2.5" strokeLinecap="round"><polyline points="5,12 10,17 19,7" /></svg>);
const MicIcon = ({ size = 24, color = 'currentColor' }) => (<svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2" strokeLinecap="round"><rect x="9" y="2" width="6" height="12" rx="3" /><path d="M19 10v2a7 7 0 01-14 0v-2" /><line x1="12" y1="19" x2="12" y2="22" /></svg>);
const CalendarIcon = ({ size = 24, color = 'currentColor' }) => (<svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2" strokeLinecap="round"><rect x="3" y="4" width="18" height="18" rx="3" /><line x1="16" y1="2" x2="16" y2="6" /><line x1="8" y1="2" x2="8" y2="6" /><line x1="3" y1="10" x2="21" y2="10" /></svg>);
const XIcon = ({ size = 24, color = 'currentColor' }) => (<svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2.5" strokeLinecap="round"><line x1="18" y1="6" x2="6" y2="18" /><line x1="6" y1="6" x2="18" y2="18" /></svg>);
const ChevronRightIcon = ({ size = 24, color = 'currentColor' }) => (<svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2" strokeLinecap="round"><polyline points="9,6 15,12 9,18" /></svg>);
const LeafIcon = ({ size = 24, color = 'currentColor' }) => (<svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2" strokeLinecap="round"><path d="M11 20A7 7 0 0 1 9.8 6.1C15.5 5 17 4.48 19 2c1 2 2 4.18 2 8 0 5.5-4.78 10-10 10Z" /><path d="M2 21c0-3 1.85-5.36 5.08-6C9.5 14.52 12 13 13 12" /></svg>);

// Main App Component
const MemossDesignSystem = () => {
  const [activeScreen, setActiveScreen] = useState('list');
  const [reminders, setReminders] = useState([
    { id: 1, title: 'Water the plants 🌱', time: '9:00 AM', completed: false, priority: 'high' },
    { id: 2, title: 'Call mom for her birthday', time: '11:00 AM', completed: false },
    { id: 3, title: 'Pick up groceries', time: '2:00 PM', completed: true },
    { id: 4, title: 'Take Buddy to the vet', time: '3:00 PM', completed: false, tags: ['Buddy'] },
    { id: 5, title: 'Finish project presentation', time: '5:00 PM', completed: false },
    { id: 6, title: 'Evening meditation', time: '8:00 PM', completed: false, recurrence: 'Daily' },
  ]);

  const toggleReminder = (id) => setReminders(reminders.map(r => r.id === id ? { ...r, completed: !r.completed } : r));

  const screens = { list: 'Reminders', create: 'Create', empty: 'Empty', success: 'Success', voice: 'Voice', system: 'Design System' };

  return (
    <div style={{ minHeight: '100vh', background: `linear-gradient(180deg, ${tokens.colors.neutral[100]} 0%, ${tokens.colors.primary[50]} 100%)`, fontFamily: tokens.typography.fontFamily.body }}>
      <style>{baseStyles}</style>
      
      {/* Navigation */}
      <div style={{ background: tokens.colors.neutral[0], borderBottom: `1px solid ${tokens.colors.neutral[200]}`, padding: `${tokens.spacing[3]} ${tokens.spacing[4]}`, position: 'sticky', top: 0, zIndex: 100 }}>
        <div style={{ maxWidth: '1200px', margin: '0 auto', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: tokens.spacing[3] }}>
            <MossMascot size={50} mood="happy" />
            <div>
              <h1 style={{ fontFamily: tokens.typography.fontFamily.display, fontSize: tokens.typography.fontSize.xl, fontWeight: tokens.typography.fontWeight.extrabold, color: tokens.colors.primary[600], margin: 0 }}>memoss</h1>
              <p style={{ fontSize: tokens.typography.fontSize.xs, color: tokens.colors.neutral[500], margin: 0 }}>your reminder</p>
            </div>
          </div>
          <div style={{ display: 'flex', gap: tokens.spacing[2], flexWrap: 'wrap' }}>
            {Object.entries(screens).map(([key, label]) => (
              <Button key={key} variant={activeScreen === key ? 'primary' : 'ghost'} size="sm" onClick={() => setActiveScreen(key)}>{label}</Button>
            ))}
          </div>
        </div>
      </div>

      {/* Main Content */}
      <div style={{ maxWidth: '1200px', margin: '0 auto', padding: tokens.spacing[6], display: 'grid', gridTemplateColumns: activeScreen === 'system' ? '1fr' : '400px 1fr', gap: tokens.spacing[8] }}>
        
        {/* Phone Preview */}
        {activeScreen !== 'system' && (
          <div style={{ background: tokens.colors.neutral[900], borderRadius: '48px', padding: '14px', boxShadow: tokens.shadows.xl, height: 'fit-content', position: 'sticky', top: '100px' }}>
            <div style={{ background: tokens.colors.neutral[50], borderRadius: '38px', overflow: 'hidden', height: '800px', position: 'relative' }}>
              <div style={{ padding: `${tokens.spacing[2]} ${tokens.spacing[5]}`, display: 'flex', justifyContent: 'space-between', alignItems: 'center', fontSize: tokens.typography.fontSize.sm, fontWeight: tokens.typography.fontWeight.semibold }}>
                <span>9:41</span>
                <div style={{ display: 'flex', gap: tokens.spacing[1] }}><span>📶</span><span>🔋</span></div>
              </div>
              <div style={{ height: 'calc(100% - 40px)', overflow: 'auto' }}>
                {activeScreen === 'list' && <ReminderListScreen reminders={reminders} toggleReminder={toggleReminder} />}
                {activeScreen === 'create' && <CreateReminderScreen />}
                {activeScreen === 'empty' && <EmptyStateScreen />}
                {activeScreen === 'success' && <SuccessScreen />}
                {activeScreen === 'voice' && <VoiceInputScreen />}
              </div>
            </div>
          </div>
        )}

        {/* Documentation Panel */}
        <div>{activeScreen === 'system' ? <DesignSystemDocs /> : <ScreenDocumentation screen={activeScreen} />}</div>
      </div>
    </div>
  );
};

// Screen Components
const ReminderListScreen = ({ reminders, toggleReminder }) => {
  const incomplete = reminders.filter(r => !r.completed);
  const completed = reminders.filter(r => r.completed);

  return (
    <div style={{ padding: tokens.spacing[5], background: `linear-gradient(180deg, ${tokens.colors.neutral[50]} 0%, ${tokens.colors.primary[50]} 100%)`, minHeight: '100%' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: tokens.spacing[5] }}>
        <div>
          <p style={{ fontFamily: tokens.typography.fontFamily.body, fontSize: tokens.typography.fontSize.base, color: tokens.colors.neutral[500], margin: 0 }}>Good morning,</p>
          <h2 style={{ fontFamily: tokens.typography.fontFamily.display, fontSize: tokens.typography.fontSize['3xl'], fontWeight: tokens.typography.fontWeight.extrabold, color: tokens.colors.neutral[900], margin: 0 }}>James 🌿</h2>
        </div>
        <MossMascot size={70} mood="happy" animate />
      </div>

      <div style={{ display: 'flex', gap: tokens.spacing[1], marginBottom: tokens.spacing[6], background: tokens.colors.neutral[0], borderRadius: tokens.borderRadius['2xl'], padding: tokens.spacing[2], boxShadow: tokens.shadows.sm }}>
        <DatePill day={21} weekday="TUE" isActive hasReminder />
        <DatePill day={22} weekday="WED" hasReminder />
        <DatePill day={23} weekday="THU" />
        <DatePill day={24} weekday="FRI" hasReminder />
        <DatePill day={25} weekday="SAT" />
      </div>

      <div style={{ marginBottom: tokens.spacing[4] }}>
        <h3 style={{ fontFamily: tokens.typography.fontFamily.display, fontSize: tokens.typography.fontSize.lg, fontWeight: tokens.typography.fontWeight.bold, color: tokens.colors.neutral[800], marginBottom: tokens.spacing[4], display: 'flex', alignItems: 'center', gap: tokens.spacing[2] }}>
          <LeafIcon size={20} color={tokens.colors.primary[500]} /> Today's tasks
        </h3>
        {incomplete.map(reminder => <ReminderCard key={reminder.id} {...reminder} onToggle={() => toggleReminder(reminder.id)} />)}
      </div>

      {completed.length > 0 && (
        <div>
          <h3 style={{ fontFamily: tokens.typography.fontFamily.display, fontSize: tokens.typography.fontSize.base, fontWeight: tokens.typography.fontWeight.semibold, color: tokens.colors.neutral[500], marginBottom: tokens.spacing[3] }}>✓ Completed</h3>
          {completed.map(reminder => <ReminderCard key={reminder.id} {...reminder} onToggle={() => toggleReminder(reminder.id)} />)}
        </div>
      )}

      <div style={{ position: 'absolute', bottom: tokens.spacing[8], right: tokens.spacing[5] }}>
        <FAB icon={<PlusIcon size={28} color={tokens.colors.neutral[0]} />} />
      </div>
    </div>
  );
};

const CreateReminderScreen = () => (
  <div style={{ padding: tokens.spacing[5], background: tokens.colors.neutral[50] }}>
    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: tokens.spacing[6] }}>
      <Button variant="ghost" size="sm" icon={<XIcon size={20} />} iconOnly />
      <h2 style={{ fontFamily: tokens.typography.fontFamily.display, fontSize: tokens.typography.fontSize.lg, fontWeight: tokens.typography.fontWeight.bold, color: tokens.colors.neutral[900], margin: 0 }}>New Reminder</h2>
      <Button variant="primary" size="sm">Save</Button>
    </div>

    <div style={{ display: 'flex', flexDirection: 'column', gap: tokens.spacing[5] }}>
      <Input label="What do you need to remember?" placeholder="e.g., Water the plants, call mom" />

      <Card variant="outlined" padding="md">
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: tokens.spacing[3] }}>
            <div style={{ width: '44px', height: '44px', borderRadius: tokens.borderRadius.lg, background: tokens.colors.primary[100], display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <CalendarIcon size={22} color={tokens.colors.primary[600]} />
            </div>
            <div>
              <p style={{ fontFamily: tokens.typography.fontFamily.display, fontSize: tokens.typography.fontSize.base, fontWeight: tokens.typography.fontWeight.bold, color: tokens.colors.neutral[800], margin: 0 }}>Today</p>
              <p style={{ fontFamily: tokens.typography.fontFamily.body, fontSize: tokens.typography.fontSize.sm, color: tokens.colors.neutral[500], margin: 0 }}>Tuesday, Jan 21</p>
            </div>
          </div>
          <ChevronRightIcon size={20} color={tokens.colors.neutral[400]} />
        </div>
      </Card>

      <Card variant="outlined" padding="md">
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: tokens.spacing[3] }}>
            <div style={{ width: '44px', height: '44px', borderRadius: tokens.borderRadius.lg, background: tokens.colors.accent[100], display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <ClockIcon size={22} color={tokens.colors.accent[600]} />
            </div>
            <div>
              <p style={{ fontFamily: tokens.typography.fontFamily.display, fontSize: tokens.typography.fontSize.base, fontWeight: tokens.typography.fontWeight.bold, color: tokens.colors.neutral[800], margin: 0 }}>9:00 AM</p>
              <p style={{ fontFamily: tokens.typography.fontFamily.body, fontSize: tokens.typography.fontSize.sm, color: tokens.colors.neutral[500], margin: 0 }}>Remind me at</p>
            </div>
          </div>
          <ChevronRightIcon size={20} color={tokens.colors.neutral[400]} />
        </div>
      </Card>

      <div>
        <p style={{ fontFamily: tokens.typography.fontFamily.display, fontSize: tokens.typography.fontSize.sm, fontWeight: tokens.typography.fontWeight.semibold, color: tokens.colors.neutral[700], marginBottom: tokens.spacing[3] }}>Tags</p>
        <div style={{ display: 'flex', gap: tokens.spacing[2], flexWrap: 'wrap' }}>
          <Badge variant="primary">+ Work</Badge>
          <Badge variant="secondary">+ Personal</Badge>
          <Badge variant="accent">+ Health</Badge>
          <Badge variant="pink">+ Urgent</Badge>
        </div>
      </div>
    </div>
  </div>
);

const EmptyStateScreen = () => (
  <div style={{ padding: tokens.spacing[5], height: '100%', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', textAlign: 'center', background: `linear-gradient(180deg, ${tokens.colors.neutral[50]} 0%, ${tokens.colors.primary[50]} 100%)` }}>
    <MossMascot size={160} mood="calm" animate />
    <h2 style={{ fontFamily: tokens.typography.fontFamily.display, fontSize: tokens.typography.fontSize['2xl'], fontWeight: tokens.typography.fontWeight.extrabold, color: tokens.colors.neutral[900], marginBottom: tokens.spacing[3], marginTop: tokens.spacing[6] }}>All clear! 🌿</h2>
    <p style={{ fontFamily: tokens.typography.fontFamily.body, fontSize: tokens.typography.fontSize.base, color: tokens.colors.neutral[500], marginBottom: tokens.spacing[8], maxWidth: '260px', lineHeight: 1.6 }}>No reminders for today. Time to relax and enjoy the moment!</p>
    <Button variant="primary" icon={<PlusIcon size={20} />}>Add Reminder</Button>
  </div>
);

const SuccessScreen = () => (
  <div style={{ padding: tokens.spacing[5], height: '100%', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', textAlign: 'center', background: `linear-gradient(180deg, ${tokens.colors.primary[50]} 0%, ${tokens.colors.primary[100]} 100%)` }}>
    <div style={{ width: '110px', height: '110px', borderRadius: tokens.borderRadius.full, background: tokens.colors.primary[500], display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: tokens.spacing[6], boxShadow: `0 0 0 16px ${tokens.colors.primary[100]}` }}>
      <CheckIcon size={52} color={tokens.colors.neutral[0]} />
    </div>
    <MossMascot size={80} mood="excited" animate />
    <h2 style={{ fontFamily: tokens.typography.fontFamily.display, fontSize: tokens.typography.fontSize['2xl'], fontWeight: tokens.typography.fontWeight.extrabold, color: tokens.colors.neutral[900], marginBottom: tokens.spacing[3], marginTop: tokens.spacing[4] }}>Reminder saved! ✨</h2>
    <p style={{ fontFamily: tokens.typography.fontFamily.body, fontSize: tokens.typography.fontSize.base, color: tokens.colors.neutral[600], marginBottom: tokens.spacing[2] }}>You'll be reminded on</p>
    <p style={{ fontFamily: tokens.typography.fontFamily.display, fontSize: tokens.typography.fontSize.lg, fontWeight: tokens.typography.fontWeight.bold, color: tokens.colors.primary[700], marginBottom: tokens.spacing[8] }}>Tuesday, Jan 21 at 9:00 AM</p>
    <Button variant="primary">Done</Button>
  </div>
);

const VoiceInputScreen = () => (
  <div style={{ padding: tokens.spacing[5], height: '100%', display: 'flex', flexDirection: 'column', background: tokens.colors.neutral[950] }}>
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
      <h2 style={{ fontFamily: tokens.typography.fontFamily.display, fontSize: tokens.typography.fontSize['2xl'], fontWeight: tokens.typography.fontWeight.extrabold, color: tokens.colors.neutral[0], marginBottom: tokens.spacing[4] }}>How can I help you, James?</h2>
      <p style={{ fontFamily: tokens.typography.fontFamily.body, fontSize: tokens.typography.fontSize.lg, color: tokens.colors.neutral[300], lineHeight: 1.6 }}>
        <span style={{ borderBottom: `2px solid ${tokens.colors.primary[400]}`, paddingBottom: '2px', color: tokens.colors.primary[300] }}>Remind me</span> to water the plants every morning at 9am
      </p>
    </div>
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: tokens.spacing[6], paddingBottom: tokens.spacing[8] }}>
      <div style={{ width: '88px', height: '88px', borderRadius: tokens.borderRadius.full, background: tokens.colors.neutral[0], display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: `0 0 0 10px rgba(34, 197, 94, 0.2), 0 0 0 20px rgba(34, 197, 94, 0.1)` }}>
        <MicIcon size={36} color={tokens.colors.primary[600]} />
      </div>
      <Button variant="ghost" icon={<XIcon size={24} color={tokens.colors.neutral[0]} />} iconOnly style={{ background: tokens.colors.pink[500], width: '52px', height: '52px' }} />
    </div>
  </div>
);

// Design System Documentation
const DesignSystemDocs = () => (
  <div style={{ display: 'flex', flexDirection: 'column', gap: tokens.spacing[8] }}>
    <div>
      <div style={{ display: 'flex', alignItems: 'center', gap: tokens.spacing[4], marginBottom: tokens.spacing[4] }}>
        <MossMascot size={80} mood="happy" animate />
        <div>
          <h1 style={{ fontFamily: tokens.typography.fontFamily.display, fontSize: tokens.typography.fontSize['4xl'], fontWeight: tokens.typography.fontWeight.extrabold, color: tokens.colors.primary[600], margin: 0 }}>memoss</h1>
          <p style={{ fontFamily: tokens.typography.fontFamily.body, fontSize: tokens.typography.fontSize.lg, color: tokens.colors.neutral[500], margin: 0 }}>Design System & Component Library</p>
        </div>
      </div>
      <p style={{ fontFamily: tokens.typography.fontFamily.body, fontSize: tokens.typography.fontSize.base, color: tokens.colors.neutral[600], lineHeight: 1.7, maxWidth: '700px' }}>
        A nature-inspired, friendly design system for the memoss reminder app. Built with a fresh green palette, soft shapes, and the adorable moss mascot that brings warmth to every interaction.
      </p>
    </div>

    <Card variant="elevated" padding="lg">
      <h2 style={{ fontFamily: tokens.typography.fontFamily.display, fontSize: tokens.typography.fontSize.xl, fontWeight: tokens.typography.fontWeight.bold, color: tokens.colors.neutral[900], marginBottom: tokens.spacing[4] }}>🎨 Color System</h2>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: tokens.spacing[6] }}>
        <ColorPalette name="Primary (Moss Green)" colors={tokens.colors.primary} />
        <ColorPalette name="Secondary (Sage)" colors={tokens.colors.secondary} />
        <ColorPalette name="Accent (Golden)" colors={tokens.colors.accent} />
        <ColorPalette name="Neutral" colors={tokens.colors.neutral} />
      </div>
    </Card>

    <Card variant="nature" padding="lg">
      <h2 style={{ fontFamily: tokens.typography.fontFamily.display, fontSize: tokens.typography.fontSize.xl, fontWeight: tokens.typography.fontWeight.bold, color: tokens.colors.neutral[900], marginBottom: tokens.spacing[4] }}>🌿 Moss Mascot</h2>
      <p style={{ fontFamily: tokens.typography.fontFamily.body, fontSize: tokens.typography.fontSize.base, color: tokens.colors.neutral[600], marginBottom: tokens.spacing[4] }}>Our friendly moss mascot brings personality and warmth to the app.</p>
      <div style={{ display: 'flex', gap: tokens.spacing[6], alignItems: 'center', flexWrap: 'wrap' }}>
        {['happy', 'excited', 'calm', 'sleepy'].map(mood => (
          <div key={mood} style={{ textAlign: 'center' }}>
            <MossMascot size={100} mood={mood} />
            <p style={{ fontSize: tokens.typography.fontSize.sm, color: tokens.colors.neutral[500], marginTop: tokens.spacing[2], textTransform: 'capitalize' }}>{mood}</p>
          </div>
        ))}
      </div>
    </Card>

    <Card variant="elevated" padding="lg">
      <h2 style={{ fontFamily: tokens.typography.fontFamily.display, fontSize: tokens.typography.fontSize.xl, fontWeight: tokens.typography.fontWeight.bold, color: tokens.colors.neutral[900], marginBottom: tokens.spacing[4] }}>🔘 Buttons</h2>
      <div style={{ display: 'flex', flexDirection: 'column', gap: tokens.spacing[4] }}>
        <div style={{ display: 'flex', gap: tokens.spacing[3], alignItems: 'center', flexWrap: 'wrap' }}>
          <Button variant="primary">Primary</Button>
          <Button variant="secondary">Secondary</Button>
          <Button variant="soft">Soft</Button>
          <Button variant="accent">Accent</Button>
          <Button variant="ghost">Ghost</Button>
        </div>
        <div style={{ display: 'flex', gap: tokens.spacing[3], alignItems: 'center', flexWrap: 'wrap' }}>
          <Button variant="primary" icon={<PlusIcon size={18} />}>With Icon</Button>
          <Button variant="soft" icon={<LeafIcon size={20} />} iconOnly />
          <FAB icon={<PlusIcon size={28} color={tokens.colors.neutral[0]} />} />
        </div>
      </div>
    </Card>

    <Card variant="elevated" padding="lg">
      <h2 style={{ fontFamily: tokens.typography.fontFamily.display, fontSize: tokens.typography.fontSize.xl, fontWeight: tokens.typography.fontWeight.bold, color: tokens.colors.neutral[900], marginBottom: tokens.spacing[4] }}>🏷️ Badges</h2>
      <div style={{ display: 'flex', gap: tokens.spacing[3], flexWrap: 'wrap' }}>
        <Badge variant="default">Default</Badge>
        <Badge variant="primary">Primary</Badge>
        <Badge variant="secondary">Secondary</Badge>
        <Badge variant="accent">Accent</Badge>
        <Badge variant="pink">Pink</Badge>
      </div>
    </Card>
  </div>
);

const ColorPalette = ({ name, colors }) => {
  const colorEntries = Object.entries(colors).filter(([key]) => !isNaN(key));
  return (
    <div>
      <h4 style={{ fontFamily: tokens.typography.fontFamily.display, fontSize: tokens.typography.fontSize.sm, fontWeight: tokens.typography.fontWeight.bold, color: tokens.colors.neutral[700], marginBottom: tokens.spacing[3] }}>{name}</h4>
      <div style={{ display: 'flex', flexDirection: 'column', gap: '2px' }}>
        {colorEntries.slice(0, 7).map(([shade, color]) => (
          <div key={shade} style={{ display: 'flex', alignItems: 'center', gap: tokens.spacing[3] }}>
            <div style={{ width: '40px', height: '20px', background: color, borderRadius: tokens.borderRadius.sm, border: shade === '0' || shade === '50' ? `1px solid ${tokens.colors.neutral[200]}` : 'none' }} />
            <span style={{ fontFamily: tokens.typography.fontFamily.body, fontSize: tokens.typography.fontSize.xs, color: tokens.colors.neutral[600] }}>{shade}</span>
          </div>
        ))}
      </div>
    </div>
  );
};

const ScreenDocumentation = ({ screen }) => {
  const docs = {
    list: { title: 'Reminder List', description: 'The main home screen with moss mascot greeting, date selector, and organized task list.' },
    create: { title: 'Create Reminder', description: 'Form interface for creating new reminders with date, time, and tags.' },
    empty: { title: 'Empty State', description: 'Friendly empty state with calm moss mascot when no reminders exist.' },
    success: { title: 'Success', description: 'Celebration screen with excited moss mascot after saving a reminder.' },
    voice: { title: 'Voice Input', description: 'Voice-to-text interface for natural language reminder creation.' },
  };
  const doc = docs[screen];
  return (
    <div>
      <h2 style={{ fontFamily: tokens.typography.fontFamily.display, fontSize: tokens.typography.fontSize['2xl'], fontWeight: tokens.typography.fontWeight.extrabold, color: tokens.colors.neutral[900], marginBottom: tokens.spacing[3] }}>{doc.title}</h2>
      <p style={{ fontFamily: tokens.typography.fontFamily.body, fontSize: tokens.typography.fontSize.base, color: tokens.colors.neutral[600], lineHeight: 1.7 }}>{doc.description}</p>
    </div>
  );
};

export default MemossDesignSystem;
