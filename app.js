/**
 * AgriLoop — Application Architecture & Simulation Engine
 * Modern Community Composting & Smart Bokashi Bin Ecosystem
 */

// ===================================================================
// 1. STATE STORE (Supabase / Local DB Simulation)
// ===================================================================

const AgriState = {
  activeRole: 'resident', // 'resident' | 'merchant' | 'operator'
  deviceMode: 'mobile',   // 'mobile' | 'full'
  
  // Resident Profile
  profile: {
    nickname: 'Norah Lee',
    township: 'City of Elmina (Elmina Valley)',
    block: 'Block A',
    unit: '12-03',
    inviteCode: 'ELM-9921',
    verified: true,
    points: 1450,
    streakWeeks: 4,
    totalKgDiverted: 18.4,
    co2Factor: 2.5 // 1 kg food waste = 2.5 kg CO2e avoided (IPCC & US EPA WARM)
  },

  // Nearest Smart Bin Status (ESP32 telemetry)
  bins: [
    {
      id: 'A01',
      name: 'Ground Foyer (Elmina Green)',
      status: 'available', // available | full | offline
      weight_g: 8420,
      fill_pct: 42,
      temp_c: 31.2,
      humidity_pct: 64,
      rssi: -61,
      lock: 'locked',
      lastSeen: 'Just now'
    },
    {
      id: 'B02',
      name: 'Central Park West Walkway',
      status: 'available',
      weight_g: 16800,
      fill_pct: 84,
      temp_c: 32.5,
      humidity_pct: 68,
      rssi: -69,
      lock: 'locked',
      lastSeen: '1 min ago'
    },
    {
      id: 'C03',
      name: 'Clubhouse & Nursery Deck',
      status: 'available',
      weight_g: 6200,
      fill_pct: 31,
      temp_c: 29.8,
      humidity_pct: 61,
      rssi: -58,
      lock: 'locked',
      lastSeen: '3 mins ago'
    }
  ],

  // Community Progress
  community: {
    targetCompostKg: 100,
    currentCompostKg: 62,
    blocks: [
      { name: 'Block A (Your Block)', kg: 142.8, rank: 1, isUser: true },
      { name: 'Block B', kg: 128.4, rank: 2, isUser: false },
      { name: 'Block C', kg: 94.6, rank: 3, isUser: false }
    ]
  },

  // Partner Voucher Catalogue
  voucherCatalog: [
    {
      id: 'cat-jg-5',
      merchant: 'Jaya Grocer',
      icon: '🛒',
      title: 'RM 5.00 Grocery Voucher',
      costPts: 1000,
      terms: 'Valid on fresh produce & grocery staples across all Sime Darby township branches.',
      expiryDays: 30
    },
    {
      id: 'cat-zus-5',
      merchant: 'Zus Coffee',
      icon: '☕',
      title: 'RM 5.00 Handcrafted Beverage',
      costPts: 900,
      terms: 'Applicable in Zus Coffee app or in-store scan at Elmina lakeside kiosk.',
      expiryDays: 14
    },
    {
      id: 'cat-tea-5',
      merchant: 'Tealive',
      icon: '🧋',
      title: 'RM 5.00 Tea Voucher',
      costPts: 900,
      terms: 'Valid for any handcrafted tea or eco-friendly reusable tumbler order.',
      expiryDays: 21
    },
    {
      id: 'cat-vg-10',
      merchant: 'Village Grocer',
      icon: '🥬',
      title: 'RM 10.00 Organic Produce Pass',
      costPts: 1900,
      terms: 'Minimum spend RM 30 in organic fruit and vegetable section.',
      expiryDays: 45
    }
  ],

  // Resident's Issued Vouchers
  myVouchers: [
    {
      id: 'VOUCH-9921-A',
      catalogId: 'cat-jg-5',
      merchant: 'Jaya Grocer',
      title: 'RM 5.00 Grocery Voucher',
      token: 'AGR-JG-5-A93F-SEC',
      status: 'active', // active | used | expired
      issuedDate: '2026-10-18',
      expiryDate: '2026-11-17'
    }
  ],

  // Merchant Redemptions Log (Today)
  merchantRedemptions: [
    { time: '09:15 AM', user: 'Unit 08-04 (Kelvin T.)', value: 5.00, token: 'AGR-JG-5-B77C' },
    { time: '11:42 AM', user: 'Unit 14-02 (Aishah R.)', value: 5.00, token: 'AGR-JG-5-F21E' },
    { time: '02:08 PM', user: 'Unit 03-11 (Marcus W.)', value: 10.00, token: 'AGR-VG-10-992C' }
  ],

  // Deposit History
  deposits: [
    {
      id: 'DEP-8841',
      date: 'Yesterday, 6:45 PM',
      binId: 'A01',
      weightKg: 0.72,
      points: 79,
      clean: true,
      thumb: 'assets/deposit_clean.jpg',
      verdict: 'Clean organic scraps + Bokashi bran'
    },
    {
      id: 'DEP-8832',
      date: '18 Oct 2026, 8:12 AM',
      binId: 'A01',
      weightKg: 0.95,
      points: 105,
      clean: true,
      thumb: 'assets/deposit_clean.jpg',
      verdict: 'Clean fruit trimmings and coffee grounds'
    },
    {
      id: 'DEP-8819',
      date: '16 Oct 2026, 7:20 PM',
      binId: 'B02',
      weightKg: 0.54,
      points: 59,
      clean: true,
      thumb: 'assets/deposit_clean.jpg',
      verdict: 'Vegetables & cooked rice leftovers'
    }
  ],

  // Operator Tasks
  operatorTasks: [
    { id: 'T-101', binId: 'B02', title: 'Swap 20L Bucket & Seal', desc: 'Bucket reaches 84% fill level. Transfer to curing bay.', priority: 'high' },
    { id: 'T-102', binId: 'A01', title: 'Refill Bokashi Microbial Bran', desc: 'Top up hopper dispenser with fresh bran specks.', priority: 'medium' },
    { id: 'T-103', binId: 'C03', title: 'Drain Bokashi Tea Tap', desc: 'Harvest concentrated liquid microbial feed for community planters.', priority: 'low' }
  ],

  // Operator Bokashi Fermentation Batches
  batches: [
    { id: 'Batch B-03', binSource: 'Bin A01', sealedDate: '14 Oct 2026', readyDate: '28 Oct 2026', dayCurrent: 8, dayTotal: 14, status: 'Fermenting (Anaerobic)' },
    { id: 'Batch B-02', binSource: 'Bin B02', sealedDate: '06 Oct 2026', readyDate: '20 Oct 2026', dayCurrent: 14, dayTotal: 14, status: 'Ready for Garden Soil Incorporation' },
    { id: 'Batch B-01', binSource: 'Bin C03', sealedDate: '28 Sep 2026', readyDate: '12 Oct 2026', dayCurrent: 14, dayTotal: 14, status: 'Completed & Returned to Central Planters' }
  ],

  // Operator Review Queue (Flagged / Low-confidence AI)
  reviewQueue: [
    {
      id: 'REV-402',
      depositId: 'DEP-9022',
      user: 'Unit 12-03 (Norah Lee)',
      binId: 'A01',
      weightKg: 0.82,
      reason: 'AI detected blue polyethylene bag & plastic fork',
      img: 'assets/deposit_contaminated.jpg',
      confidence: '78% (Operator Verification Required)'
    }
  ],

  // In-App Notifications Inbox
  notifications: [
    {
      id: 'N-01',
      type: 'deposit',
      unread: true,
      title: 'Deposit Successful (+79 pts)',
      body: '0.72 kg organic waste diverted at Bin A01. Thank you for enriching Elmina soil!',
      time: 'Yesterday at 6:46 PM'
    },
    {
      id: 'N-02',
      type: 'rewards',
      unread: true,
      title: 'RM 5.00 Jaya Grocer Voucher Issued',
      body: 'Your voucher is active and ready to be scanned at the cashier checkout.',
      time: '2 days ago'
    },
    {
      id: 'N-03',
      type: 'alert',
      unread: false,
      title: 'Bin B02 Approaching Capacity (84%)',
      body: 'If visiting Central Park West, please consider using Bin A01 at Ground Foyer.',
      time: '3 days ago'
    }
  ]
};

// ===================================================================
// 2. SYNTHESIZED AUDIO SOUND EFFECTS (Web Audio API)
// ===================================================================

const SoundEffects = {
  ctx: null,
  init() {
    if (!this.ctx && (window.AudioContext || window.webkitAudioContext)) {
      this.ctx = new (window.AudioContext || window.webkitAudioContext)();
    }
  },
  playUnlockClick() {
    this.init();
    if (!this.ctx) return;
    const now = this.ctx.currentTime;
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    osc.type = 'triangle';
    osc.frequency.setValueAtTime(140, now);
    osc.frequency.exponentialRampToValueAtTime(40, now + 0.08);
    gain.gain.setValueAtTime(0.4, now);
    gain.gain.exponentialRampToValueAtTime(0.01, now + 0.08);
    osc.connect(gain);
    gain.connect(this.ctx.destination);
    osc.start(now);
    osc.stop(now + 0.08);
  },
  playScanBeep() {
    this.init();
    if (!this.ctx) return;
    const now = this.ctx.currentTime;
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    osc.type = 'sine';
    osc.frequency.setValueAtTime(1200, now);
    osc.frequency.setValueAtTime(1600, now + 0.04);
    gain.gain.setValueAtTime(0.2, now);
    gain.gain.exponentialRampToValueAtTime(0.01, now + 0.09);
    osc.connect(gain);
    gain.connect(this.ctx.destination);
    osc.start(now);
    osc.stop(now + 0.09);
  },
  playSuccessChime() {
    this.init();
    if (!this.ctx) return;
    const notes = [523.25, 659.25, 783.99, 1046.50]; // C5, E5, G5, C6
    notes.forEach((freq, idx) => {
      const now = this.ctx.currentTime + idx * 0.08;
      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();
      osc.type = 'sine';
      osc.frequency.setValueAtTime(freq, now);
      gain.gain.setValueAtTime(0.25, now);
      gain.gain.exponentialRampToValueAtTime(0.01, now + 0.25);
      osc.connect(gain);
      gain.connect(this.ctx.destination);
      osc.start(now);
      osc.stop(now + 0.25);
    });
  },
  playAlertWarning() {
    this.init();
    if (!this.ctx) return;
    const now = this.ctx.currentTime;
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    osc.type = 'sawtooth';
    osc.frequency.setValueAtTime(260, now);
    osc.frequency.setValueAtTime(220, now + 0.12);
    gain.gain.setValueAtTime(0.25, now);
    gain.gain.exponentialRampToValueAtTime(0.01, now + 0.28);
    osc.connect(gain);
    gain.connect(this.ctx.destination);
    osc.start(now);
    osc.stop(now + 0.28);
  },
  playButtonPop(pitch = 1) {
    this.init();
    if (!this.ctx) return;
    const now = this.ctx.currentTime;
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    osc.type = 'sine';
    const startFreq = 480 * pitch;
    const endFreq = 200 * pitch;
    osc.frequency.setValueAtTime(startFreq, now);
    osc.frequency.exponentialRampToValueAtTime(endFreq, now + 0.04);
    gain.gain.setValueAtTime(0.18, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.04);
    osc.connect(gain);
    gain.connect(this.ctx.destination);
    osc.start(now);
    osc.stop(now + 0.04);
  }
};

// ===================================================================
// BUTTON INTERACTION & HAPTIC PARTICLES ENGINE
// ===================================================================

const ButtonFX = {
  colors: ['#22c55e', '#a3e635', '#4ade80', '#fbbf24', '#06b6d4', '#ffffff'],

  init() {
    document.addEventListener('pointerdown', (e) => this.handlePointerDown(e), true);
  },

  handlePointerDown(e) {
    const selector = 'button, .role-btn, .tab-nav-btn, .menu-item-btn, .filter-pill, .op-action-btn-sm, .task-btn, .queue-btn, .view-qr-btn, .redeem-mini-btn, .action-outline-btn, .view-toggle-btn, .sim-trigger-btn, .primary-scan-action-btn, .primary-cta-btn, .inbox-bell-btn, .op-emergency-unlock-btn, .sub-tab-btn, .modal-close-btn, .dispute-btn';
    const btn = e.target.closest(selector);
    if (!btn) return;

    // 1. Audio Click Synthesis
    SoundEffects.playButtonPop();

    // 2. Ripple Wave inside Button
    const rect = btn.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    const size = Math.max(rect.width, rect.height) * 2.2;

    const ripple = document.createElement('span');
    ripple.className = 'btn-click-ripple';
    ripple.style.width = `${size}px`;
    ripple.style.height = `${size}px`;
    ripple.style.left = `${x}px`;
    ripple.style.top = `${y}px`;

    btn.appendChild(ripple);
    setTimeout(() => ripple.remove(), 550);

    // 3. Screen Touch Shockwave Ring
    this.createShockwave(e.clientX, e.clientY);

    // 4. Sparkle Particle Burst on Interactive Buttons
    this.createSparkles(e.clientX, e.clientY, 8);
  },

  createShockwave(x, y) {
    const wave = document.createElement('div');
    wave.className = 'touch-shockwave';
    wave.style.left = `${x}px`;
    wave.style.top = `${y}px`;
    document.body.appendChild(wave);
    setTimeout(() => wave.remove(), 450);
  },

  createSparkles(x, y, count = 8) {
    for (let i = 0; i < count; i++) {
      const p = document.createElement('div');
      p.className = 'eco-sparkle-particle';
      const angle = (i / count) * 2 * Math.PI + (Math.random() - 0.5) * 0.4;
      const dist = 28 + Math.random() * 40;
      const tx = Math.cos(angle) * dist;
      const ty = Math.sin(angle) * dist;
      const color = this.colors[Math.floor(Math.random() * this.colors.length)];

      p.style.left = `${x}px`;
      p.style.top = `${y}px`;
      p.style.color = color;
      p.style.background = color;
      p.style.setProperty('--tx', `${tx}px`);
      p.style.setProperty('--ty', `${ty}px`);

      document.body.appendChild(p);
      setTimeout(() => p.remove(), 600);
    }
  }
};

// ===================================================================
// REAL DEVICE CAMERA QR SCANNER ENGINE
// ===================================================================

const CameraScanner = {
  residentStream: null,
  merchantStream: null,
  detector: null,
  residentInterval: null,
  merchantInterval: null,
  residentFacing: 'environment', // 'environment' or 'user'
  merchantFacing: 'environment',

  async init() {
    if ('BarcodeDetector' in window) {
      try {
        const formats = await BarcodeDetector.getSupportedFormats();
        if (formats.includes('qr_code')) {
          this.detector = new BarcodeDetector({ formats: ['qr_code'] });
        }
      } catch (e) {
        console.warn('BarcodeDetector initialization:', e);
      }
    }
    this.bindControls();
  },

  bindControls() {
    // Resident Camera Controls
    document.getElementById('btn-toggle-resident-cam')?.addEventListener('click', () => {
      if (this.residentStream) {
        this.stopResidentCamera();
      } else {
        this.startResidentCamera();
      }
    });

    document.getElementById('btn-flip-resident-cam')?.addEventListener('click', () => {
      this.residentFacing = this.residentFacing === 'environment' ? 'user' : 'environment';
      this.startResidentCamera();
    });

    document.getElementById('btn-request-resident-cam')?.addEventListener('click', () => {
      this.startResidentCamera();
    });

    // Merchant Camera Controls
    document.getElementById('btn-toggle-merchant-cam')?.addEventListener('click', () => {
      if (this.merchantStream) {
        this.stopMerchantCamera();
      } else {
        this.startMerchantCamera();
      }
    });

    document.getElementById('btn-flip-merchant-cam')?.addEventListener('click', () => {
      this.merchantFacing = this.merchantFacing === 'environment' ? 'user' : 'environment';
      this.startMerchantCamera();
    });

    document.getElementById('btn-request-merchant-cam')?.addEventListener('click', () => {
      this.startMerchantCamera();
    });
  },

  async startResidentCamera() {
    const video = document.getElementById('resident-live-camera');
    const label = document.getElementById('resident-cam-label');
    const mockPreview = document.getElementById('qr-target-preview');
    const promptOverlay = document.getElementById('resident-cam-prompt');
    if (!video) return;

    this.stopResidentCamera(false);

    try {
      if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        throw new Error('Camera API not supported in this browser context.');
      }

      let constraints = {
        video: {
          facingMode: { ideal: this.residentFacing },
          width: { ideal: 1280 },
          height: { ideal: 720 }
        }
      };

      try {
        this.residentStream = await navigator.mediaDevices.getUserMedia(constraints);
      } catch (err1) {
        // Fallback without constraints for webcams / laptop front cameras
        this.residentStream = await navigator.mediaDevices.getUserMedia({ video: true });
      }

      video.srcObject = this.residentStream;
      await video.play();

      if (label) label.textContent = 'Device Camera Live';
      if (mockPreview) mockPreview.style.display = 'none';
      if (promptOverlay) promptOverlay.style.display = 'none';

      this.startResidentLoop(video);
    } catch (err) {
      console.warn('Resident camera access error:', err);
      if (label) label.textContent = 'Camera Off (Click to Start)';
      if (mockPreview) mockPreview.style.display = 'flex';
      if (promptOverlay) promptOverlay.style.display = 'flex';
    }
  },

  stopResidentCamera(updateUI = true) {
    if (this.residentInterval) {
      clearInterval(this.residentInterval);
      this.residentInterval = null;
    }
    if (this.residentStream) {
      this.residentStream.getTracks().forEach(t => t.stop());
      this.residentStream = null;
    }
    const video = document.getElementById('resident-live-camera');
    if (video) video.srcObject = null;

    if (updateUI) {
      const label = document.getElementById('resident-cam-label');
      const mockPreview = document.getElementById('qr-target-preview');
      const promptOverlay = document.getElementById('resident-cam-prompt');
      if (label) label.textContent = 'Camera Paused';
      if (mockPreview) mockPreview.style.display = 'flex';
      if (promptOverlay) promptOverlay.style.display = 'flex';
    }
  },

  startResidentLoop(video) {
    if (this.residentInterval) clearInterval(this.residentInterval);
    const canvas = document.getElementById('resident-qr-canvas') || document.createElement('canvas');
    const ctx = canvas.getContext('2d', { willReadFrequently: true });
    let scanned = false;

    this.residentInterval = setInterval(async () => {
      if (scanned || video.readyState < 2) return;

      // 1. Try native BarcodeDetector
      if (this.detector) {
        try {
          const codes = await this.detector.detect(video);
          if (codes.length > 0 && codes[0].rawValue) {
            scanned = true;
            AppUI.handleCameraScannedCode(codes[0].rawValue);
            return;
          }
        } catch (e) {}
      }

      // 2. High-speed jsQR reading from camera canvas
      if (window.jsQR && video.videoWidth > 0 && video.videoHeight > 0) {
        try {
          canvas.width = video.videoWidth;
          canvas.height = video.videoHeight;
          ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
          const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
          const code = window.jsQR(imageData.data, imageData.width, imageData.height, {
            inversionAttempts: 'dontInvert'
          });
          if (code && code.data) {
            scanned = true;
            AppUI.handleCameraScannedCode(code.data);
          }
        } catch (e) {}
      }
    }, 250);
  },

  async startMerchantCamera() {
    const video = document.getElementById('merchant-live-camera');
    const label = document.getElementById('merchant-cam-label');
    const promptOverlay = document.getElementById('merchant-cam-prompt');
    if (!video) return;

    this.stopMerchantCamera(false);

    try {
      if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        throw new Error('Camera API not supported');
      }

      let constraints = {
        video: {
          facingMode: { ideal: this.merchantFacing },
          width: { ideal: 1280 },
          height: { ideal: 720 }
        }
      };

      try {
        this.merchantStream = await navigator.mediaDevices.getUserMedia(constraints);
      } catch (e) {
        this.merchantStream = await navigator.mediaDevices.getUserMedia({ video: true });
      }

      video.srcObject = this.merchantStream;
      await video.play();

      if (label) label.textContent = 'Cashier Cam Live';
      if (promptOverlay) promptOverlay.style.display = 'none';

      this.startMerchantLoop(video);
    } catch (err) {
      console.warn('Merchant camera access error:', err);
      if (label) label.textContent = 'Camera Off (Click to Start)';
      if (promptOverlay) promptOverlay.style.display = 'flex';
    }
  },

  stopMerchantCamera(updateUI = true) {
    if (this.merchantInterval) {
      clearInterval(this.merchantInterval);
      this.merchantInterval = null;
    }
    if (this.merchantStream) {
      this.merchantStream.getTracks().forEach(t => t.stop());
      this.merchantStream = null;
    }
    const video = document.getElementById('merchant-live-camera');
    if (video) video.srcObject = null;

    if (updateUI) {
      const label = document.getElementById('merchant-cam-label');
      const promptOverlay = document.getElementById('merchant-cam-prompt');
      if (label) label.textContent = 'Camera Paused';
      if (promptOverlay) promptOverlay.style.display = 'flex';
    }
  },

  startMerchantLoop(video) {
    if (this.merchantInterval) clearInterval(this.merchantInterval);
    const canvas = document.getElementById('merchant-qr-canvas') || document.createElement('canvas');
    const ctx = canvas.getContext('2d', { willReadFrequently: true });
    let scanned = false;

    this.merchantInterval = setInterval(async () => {
      if (scanned || video.readyState < 2) return;

      if (this.detector) {
        try {
          const codes = await this.detector.detect(video);
          if (codes.length > 0 && codes[0].rawValue) {
            scanned = true;
            AppUI.handleMerchantScannedCode(codes[0].rawValue);
            return;
          }
        } catch (e) {}
      }

      if (window.jsQR && video.videoWidth > 0 && video.videoHeight > 0) {
        try {
          canvas.width = video.videoWidth;
          canvas.height = video.videoHeight;
          ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
          const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
          const code = window.jsQR(imageData.data, imageData.width, imageData.height);
          if (code && code.data) {
            scanned = true;
            AppUI.handleMerchantScannedCode(code.data);
          }
        } catch (e) {}
      }
    }, 250);
  },

  stopAll() {
    this.stopResidentCamera();
    this.stopMerchantCamera();
  }
};

// ===================================================================
// 3. UI CONTROLLER & RENDERING ENGINE
// ===================================================================

const AppUI = {
  countdownTimer: null,
  activeDepositMode: 'clean', // 'clean' | 'contaminated'

  init() {
    ButtonFX.init();
    CameraScanner.init();
    this.updateClock();
    setInterval(() => this.updateClock(), 30000);
    this.rotateQRNonce();
    setInterval(() => this.rotateQRNonce(), 30000);

    this.bindGlobalNavigation();
    this.bindResidentTabs();
    this.bindDepositWorkflow();
    this.bindRewardsTabs();
    this.bindModals();
    this.bindMerchantControls();
    this.bindOperatorControls();

    this.renderAllViews();
  },

  showToast(message, type = 'info') {
    let toast = document.getElementById('app-dynamic-toast');
    if (!toast) {
      toast = document.createElement('div');
      toast.id = 'app-dynamic-toast';
      toast.style.cssText = `
        position: fixed;
        bottom: 74px;
        left: 50%;
        transform: translateX(-50%) translateY(20px);
        background: #111e17;
        border: 1px solid #22c55e;
        color: #f0fdf4;
        padding: 10px 18px;
        border-radius: 24px;
        font-size: 0.8rem;
        font-weight: 600;
        z-index: 9999;
        box-shadow: 0 8px 24px rgba(0,0,0,0.5);
        opacity: 0;
        pointer-events: none;
        transition: all 0.25s cubic-bezier(0.16, 1, 0.3, 1);
        display: flex;
        align-items: center;
        gap: 8px;
        max-width: 90%;
        text-align: center;
      `;
      document.body.appendChild(toast);
    }
    toast.textContent = message;
    toast.style.opacity = '1';
    toast.style.transform = 'translateX(-50%) translateY(0)';
    setTimeout(() => {
      toast.style.opacity = '0';
      toast.style.transform = 'translateX(-50%) translateY(20px)';
    }, 3200);
  },

  handleCameraScannedCode(code) {
    SoundEffects.playScanBeep();
    this.showToast(`📷 Scanned QR: ${code.substring(0, 18)}... Starting unlock sequence!`, 'success');
    this.startUnlockSequence();
  },

  handleMerchantScannedCode(token) {
    SoundEffects.playScanBeep();
    setTimeout(() => {
      SoundEffects.playSuccessChime();
      const newRecord = {
        time: 'Just now',
        user: `${AgriState.profile.unit} (${AgriState.profile.nickname})`,
        value: 5.00,
        token: token.substring(0, 16)
      };
      AgriState.merchantRedemptions.unshift(newRecord);
      this.showToast(`✓ Scanned Customer Voucher: RM 5.00 applied!`, 'success');
      this.renderMerchantView();
    }, 400);
  },

  updateClock() {
    const now = new Date();
    const hrs = String(now.getHours()).padStart(2, '0');
    const mins = String(now.getMinutes()).padStart(2, '0');
    const el = document.getElementById('status-time');
    if (el) el.textContent = `${hrs}:${mins}`;
  },

  rotateQRNonce() {
    const chars = '0123456789ABCDEF';
    let nonce = '';
    for (let i = 0; i < 8; i++) {
      if (i === 4) nonce += '-';
      nonce += chars[Math.floor(Math.random() * chars.length)];
    }
    const nonceEl = document.getElementById('mock-qr-nonce');
    if (nonceEl) nonceEl.textContent = nonce;
  },

  // -----------------------------------------------------------------
  // Role & Global Nav
  // -----------------------------------------------------------------
  bindGlobalNavigation() {
    const roleBtns = document.querySelectorAll('.role-btn');
    roleBtns.forEach(btn => {
      btn.addEventListener('click', (e) => {
        const role = btn.dataset.role;
        this.switchRole(role);
      });
    });

    // Hardware Spec Drawer Toggle
    const btnHardware = document.getElementById('btn-hardware-drawer');
    const drawerHardware = document.getElementById('hardware-drawer');
    const btnCloseHardware = document.getElementById('btn-close-hardware-drawer');

    btnHardware?.addEventListener('click', () => {
      drawerHardware?.classList.toggle('open');
    });
    btnCloseHardware?.addEventListener('click', () => {
      drawerHardware?.classList.remove('open');
    });

    // Phone Frame vs Desktop Full Width Toggle
    const btnToggleFrame = document.getElementById('btn-toggle-frame');
    const appEnv = document.getElementById('app-environment');
    const frameToggleText = document.getElementById('frame-toggle-text');

    btnToggleFrame?.addEventListener('click', () => {
      appEnv.classList.toggle('full-mode');
      const isFull = appEnv.classList.contains('full-mode');
      frameToggleText.textContent = isFull ? 'Phone Frame' : 'Full View';
    });
  },

  switchRole(role) {
    AgriState.activeRole = role;

    // Update Top Pill Active States
    document.querySelectorAll('.role-btn').forEach(btn => {
      btn.classList.toggle('active', btn.dataset.role === role);
    });

    // Toggle Role View Panels
    document.querySelectorAll('.role-view').forEach(view => {
      view.classList.remove('active-role-view');
    });

    const activeView = document.getElementById(`view-${role}`);
    if (activeView) activeView.classList.add('active-role-view');

    SoundEffects.playUnlockClick();

    // Auto-manage live device camera per role
    if (role === 'merchant') {
      CameraScanner.stopResidentCamera(false);
      CameraScanner.startMerchantCamera();
    } else if (role === 'resident') {
      CameraScanner.stopMerchantCamera(false);
      const activeTab = document.querySelector('#resident-viewport .active-tab-page');
      if (activeTab && activeTab.id === 'tab-res-deposit') {
        CameraScanner.startResidentCamera();
      }
    } else {
      CameraScanner.stopAll();
    }
  },

  // -----------------------------------------------------------------
  // Resident Tab Bar Navigation
  // -----------------------------------------------------------------
  bindResidentTabs() {
    const tabBtns = document.querySelectorAll('.tab-nav-btn');
    tabBtns.forEach(btn => {
      btn.addEventListener('click', () => {
        const targetTab = btn.dataset.tab;
        
        tabBtns.forEach(b => b.classList.remove('active'));
        btn.classList.add('active');

        document.querySelectorAll('#resident-viewport .tab-page').forEach(page => {
          page.classList.remove('active-tab-page');
        });

        const activePage = document.getElementById(targetTab);
        if (activePage) activePage.classList.add('active-tab-page');

        SoundEffects.playUnlockClick();

        // Control camera when entering/leaving deposit tab
        if (targetTab === 'tab-res-deposit') {
          CameraScanner.startResidentCamera();
        } else {
          CameraScanner.stopResidentCamera();
        }
      });
    });

    // Home "Quick Deposit" button jumps to Deposit tab
    document.getElementById('btn-home-quick-deposit')?.addEventListener('click', () => {
      const depositTabBtn = document.querySelector('.tab-nav-btn[data-tab="tab-res-deposit"]');
      depositTabBtn?.click();
    });

    // Checklist collapsible
    const checklistToggle = document.getElementById('checklist-toggle');
    const checklistBody = document.getElementById('checklist-body');
    checklistToggle?.addEventListener('click', () => {
      checklistBody?.classList.toggle('open');
      const chevron = checklistToggle.querySelector('.chevron-icon');
      if (chevron) {
        chevron.textContent = checklistBody.classList.contains('open') ? '▼' : '▶';
      }
    });
  },

  // -----------------------------------------------------------------
  // Deposit Workflow & Simulation Machine
  // -----------------------------------------------------------------
  bindDepositWorkflow() {
    const btnSimClean = document.getElementById('btn-sim-clean-scan');
    const btnSimContam = document.getElementById('btn-sim-contam-scan');
    const btnCloseLid = document.getElementById('btn-sim-close-lid');
    const btnFinishResult = document.getElementById('btn-result-finish');
    const btnDispute = document.getElementById('btn-trigger-dispute');

    btnSimClean?.addEventListener('click', () => {
      this.activeDepositMode = 'clean';
      this.startUnlockSequence();
    });

    btnSimContam?.addEventListener('click', () => {
      this.activeDepositMode = 'contaminated';
      this.startUnlockSequence();
    });

    btnCloseLid?.addEventListener('click', () => {
      this.startSettlingAndInspection();
    });

    btnFinishResult?.addEventListener('click', () => {
      // Reset flow to scan state
      this.setDepositFlowState('flow-scan-view');
      // Jump to home tab
      document.querySelector('.tab-nav-btn[data-tab="tab-res-home"]')?.click();
    });

    btnDispute?.addEventListener('click', () => {
      alert('Dispute ticket dispatched to on-site operator queue. Points will be held pending human review.');
      SoundEffects.playScanBeep();
      btnDispute.textContent = '✓ Dispute Submitted to Operator';
      btnDispute.disabled = true;
    });
  },

  setDepositFlowState(stateId) {
    document.querySelectorAll('.deposit-flow-state').forEach(state => {
      state.classList.remove('active-flow-state');
    });
    document.getElementById(stateId)?.classList.add('active-flow-state');
  },

  startUnlockSequence() {
    SoundEffects.playScanBeep();
    CameraScanner.stopResidentCamera(false);
    this.setDepositFlowState('flow-unlock-view');

    const headline = document.getElementById('unlock-headline');
    const subtext = document.getElementById('unlock-subtext');
    const timerSec = document.getElementById('unlock-timer-sec');
    const weightCounter = document.getElementById('live-weight-counter');

    headline.textContent = 'Connecting to Bin A01...';
    subtext.textContent = 'Verifying MQTT token & cryptographic session...';

    // Simulate Solenoid latch release after 600ms
    setTimeout(() => {
      SoundEffects.playUnlockClick();
      headline.textContent = 'Bin A01 Unlatched!';
      subtext.textContent = 'Solenoid lock open. Lid reed switch active.';
      
      // Initial weight
      const initialWeight = 8420;
      weightCounter.textContent = `${initialWeight.toLocaleString()} g`;

      // Start 30s countdown
      let remaining = 30;
      timerSec.textContent = remaining;

      if (this.countdownTimer) clearInterval(this.countdownTimer);
      this.countdownTimer = setInterval(() => {
        remaining -= 1;
        timerSec.textContent = remaining;
        if (remaining <= 0) {
          clearInterval(this.countdownTimer);
          alert('Session timed out. Solenoid relocked for security.');
          this.setDepositFlowState('flow-scan-view');
          CameraScanner.startResidentCamera();
        }
      }, 1000);

    }, 800);
  },

  startSettlingAndInspection() {
    if (this.countdownTimer) clearInterval(this.countdownTimer);
    SoundEffects.playUnlockClick();

    // Move to State 3: Settling & Processing
    this.setDepositFlowState('flow-processing-view');

    // Simulate load cell settling and AI inspection duration
    setTimeout(() => {
      this.completeDepositFlow();
    }, 2200);
  },

  completeDepositFlow() {
    const isClean = this.activeDepositMode === 'clean';
    const addedKg = isClean ? 0.65 : 0.82;
    const basePts = isClean ? Math.round(addedKg * 100) : 0;
    const streakBonus = isClean ? Math.round(basePts * 0.1) : 0;
    const totalPtsEarned = basePts + streakBonus;

    // Update Global Resident State if clean
    if (isClean) {
      AgriState.profile.points += totalPtsEarned;
      AgriState.profile.totalKgDiverted = parseFloat((AgriState.profile.totalKgDiverted + addedKg).toFixed(1));
      
      // Update Bin fill
      AgriState.bins[0].weight_g += Math.round(addedKg * 1000);
      AgriState.bins[0].fill_pct = Math.min(100, Math.round(AgriState.bins[0].fill_pct + 3));

      // Append Deposit Record
      AgriState.deposits.unshift({
        id: `DEP-${Math.floor(1000 + Math.random() * 9000)}`,
        date: 'Just now',
        binId: 'A01',
        weightKg: addedKg,
        points: totalPtsEarned,
        clean: true,
        thumb: 'assets/deposit_clean.jpg',
        verdict: 'Clean organic scraps + Bokashi bran'
      });

      // Add Notification
      AgriState.notifications.unshift({
        id: `N-${Date.now()}`,
        type: 'deposit',
        unread: true,
        title: `+${totalPtsEarned} pts Earned! (${addedKg} kg diverted)`,
        body: `Clean deposit verified at Bin A01. 4-week streak maintained!`,
        time: 'Just now'
      });

      SoundEffects.playSuccessChime();
    } else {
      // Contaminated flag
      SoundEffects.playAlertWarning();

      AgriState.deposits.unshift({
        id: `DEP-${Math.floor(1000 + Math.random() * 9000)}`,
        date: 'Just now',
        binId: 'A01',
        weightKg: addedKg,
        points: 0,
        clean: false,
        thumb: 'assets/deposit_contaminated.jpg',
        verdict: 'Flagged: Single-use plastics detected'
      });

      AgriState.notifications.unshift({
        id: `N-${Date.now()}`,
        type: 'alert',
        unread: true,
        title: '⚠️ Non-Compostable Item Flagged',
        body: `Plastic cutlery / packaging detected in deposit. Points withheld. Tap to review.`,
        time: 'Just now'
      });
    }

    // Populate Result View elements
    const resultCard = document.getElementById('deposit-result-card');
    const resultTitle = document.getElementById('result-title');
    const resultIcon = document.getElementById('result-icon-badge');
    const netWeight = document.getElementById('result-net-weight');
    const weightBefore = document.getElementById('result-weight-before');
    const weightAfter = document.getElementById('result-weight-after');
    const snapshotImg = document.getElementById('result-snapshot-img');
    const aiBox = document.getElementById('result-ai-box');
    const aiConfidence = document.getElementById('result-ai-confidence');
    const aiVerdict = document.getElementById('result-ai-verdict');
    const pointsBox = document.getElementById('result-points-box');
    const pointsValue = document.getElementById('result-points-value');
    const basePtsEl = document.getElementById('result-base-pts');
    const streakPtsEl = document.getElementById('result-streak-pts');
    const disputeBox = document.getElementById('result-dispute-box');

    netWeight.textContent = `+${addedKg.toFixed(2)} kg`;
    weightBefore.textContent = '8.42 kg';
    weightAfter.textContent = `${(8.42 + addedKg).toFixed(2)} kg`;

    if (isClean) {
      resultTitle.textContent = 'Clean Deposit Verified!';
      resultIcon.textContent = '🎉';
      snapshotImg.src = 'assets/deposit_clean.jpg';
      aiBox.style.display = 'none';
      aiConfidence.textContent = '98% Confidence';
      aiConfidence.style.color = '#a3e635';
      aiVerdict.innerHTML = '<span class="verdict-icon">✅</span><span>Clean organic scraps + Bokashi microbial bran detected. Excellent work!</span>';
      
      pointsBox.style.display = 'flex';
      pointsValue.textContent = `+${totalPtsEarned} pts`;
      basePtsEl.textContent = `+${basePts} pts`;
      streakPtsEl.textContent = `+${streakBonus} pts`;
      disputeBox.style.display = 'none';
    } else {
      resultTitle.textContent = 'Contamination Detected';
      resultIcon.textContent = '⚠️';
      snapshotImg.src = 'assets/deposit_contaminated.jpg';
      aiBox.style.display = 'block';
      aiConfidence.textContent = '91% Confidence';
      aiConfidence.style.color = '#ef4444';
      aiVerdict.innerHTML = '<span class="verdict-icon">❌</span><span>Plastic bag & plastic fork identified. Non-food materials damage Bokashi anaerobic fermentation.</span>';
      
      pointsBox.style.display = 'none';
      disputeBox.style.display = 'flex';
    }

    // Switch to Result View
    this.setDepositFlowState('flow-result-view');
    this.renderAllViews();
  },

  // -----------------------------------------------------------------
  // Rewards & Voucher Redemption
  // -----------------------------------------------------------------
  bindRewardsTabs() {
    const btnCatalog = document.getElementById('subtab-btn-catalog');
    const btnMyVouchers = document.getElementById('subtab-btn-myvouchers');
    const subviewCatalog = document.getElementById('subview-catalog');
    const subviewMyVouchers = document.getElementById('subview-myvouchers');

    btnCatalog?.addEventListener('click', () => {
      btnCatalog.classList.add('active');
      btnMyVouchers.classList.remove('active');
      subviewCatalog.classList.add('active-subview');
      subviewMyVouchers.classList.remove('active-subview');
    });

    btnMyVouchers?.addEventListener('click', () => {
      btnMyVouchers.classList.add('active');
      btnCatalog.classList.remove('active');
      subviewMyVouchers.classList.add('active-subview');
      subviewCatalog.classList.remove('active-subview');
    });
  },

  redeemVoucher(catalogId) {
    const item = AgriState.voucherCatalog.find(c => c.id === catalogId);
    if (!item) return;

    if (AgriState.profile.points < item.costPts) {
      alert(`Insufficient points! You need ${item.costPts} pts (Current: ${AgriState.profile.points} pts).`);
      return;
    }

    if (confirm(`Redeem "${item.title}" for ${item.costPts} points?`)) {
      AgriState.profile.points -= item.costPts;
      
      const newVoucher = {
        id: `VOUCH-${Math.floor(1000 + Math.random() * 9000)}`,
        catalogId: item.id,
        merchant: item.merchant,
        title: item.title,
        token: `AGR-${item.merchant.substring(0,2).toUpperCase()}-5-${Math.floor(1000 + Math.random() * 9000)}-SEC`,
        status: 'active',
        issuedDate: new Date().toISOString().split('T')[0],
        expiryDate: '2026-11-20'
      };

      AgriState.myVouchers.unshift(newVoucher);
      SoundEffects.playSuccessChime();
      this.renderAllViews();
      this.openVoucherPassModal(newVoucher);
    }
  },

  openVoucherPassModal(voucher) {
    const modal = document.getElementById('modal-voucher-qr');
    document.getElementById('voucher-pass-merchant').textContent = voucher.merchant;
    document.getElementById('voucher-pass-value').textContent = voucher.title;
    document.getElementById('voucher-pass-token').textContent = `TOKEN: ${voucher.token}`;
    modal?.classList.add('open');
  },

  // -----------------------------------------------------------------
  // Modals Binding
  // -----------------------------------------------------------------
  bindModals() {
    // Inbox Modal
    const btnInbox = document.getElementById('btn-open-inbox');
    const modalInbox = document.getElementById('modal-inbox');
    const btnCloseInbox = document.getElementById('btn-close-inbox');

    btnInbox?.addEventListener('click', () => {
      modalInbox?.classList.add('open');
      // Mark read
      AgriState.notifications.forEach(n => n.unread = false);
      this.renderInbox();
      this.renderHeader();
    });

    btnCloseInbox?.addEventListener('click', () => {
      modalInbox?.classList.remove('open');
    });

    // Onboarding / Profile Edit Modal
    const btnSwitchAccount = document.getElementById('btn-switch-account-sim');
    const modalOnboard = document.getElementById('modal-onboarding');
    const btnCloseOnboard = document.getElementById('btn-close-onboarding');

    btnSwitchAccount?.addEventListener('click', () => {
      modalOnboard?.classList.add('open');
    });
    btnCloseOnboard?.addEventListener('click', () => {
      modalOnboard?.classList.remove('open');
    });

    // Deposit History Modal
    const btnOpenHistory = document.getElementById('btn-open-deposit-history');
    const modalHistory = document.getElementById('modal-history');
    const btnCloseHistory = document.getElementById('btn-close-history');

    btnOpenHistory?.addEventListener('click', () => {
      this.renderDepositHistory();
      modalHistory?.classList.add('open');
    });
    btnCloseHistory?.addEventListener('click', () => {
      modalHistory?.classList.remove('open');
    });

    // Report Problem Modal
    const btnReport = document.getElementById('btn-report-issue');
    const modalReport = document.getElementById('modal-report');
    const btnCloseReport = document.getElementById('btn-close-report');

    btnReport?.addEventListener('click', () => {
      modalReport?.classList.add('open');
    });
    btnCloseReport?.addEventListener('click', () => {
      modalReport?.classList.remove('open');
    });

    // Voucher QR Pass Close
    document.getElementById('btn-close-voucher-qr')?.addEventListener('click', () => {
      document.getElementById('modal-voucher-qr')?.classList.remove('open');
    });

    // Test QR Modal for physical camera verification
    const modalTestQr = document.getElementById('modal-test-qr');
    const testQrImg = document.getElementById('test-qr-img');
    const testQrLabel = document.getElementById('test-qr-label');
    const btnTestQrBin = document.getElementById('btn-testqr-bin');
    const btnTestQrVoucher = document.getElementById('btn-testqr-voucher');

    document.getElementById('btn-show-test-qr')?.addEventListener('click', () => {
      modalTestQr?.classList.add('open');
    });
    document.getElementById('btn-close-test-qr')?.addEventListener('click', () => {
      modalTestQr?.classList.remove('open');
    });

    btnTestQrBin?.addEventListener('click', () => {
      btnTestQrBin.classList.add('active');
      btnTestQrVoucher?.classList.remove('active');
      if (testQrImg) testQrImg.src = 'https://api.qrserver.com/v1/create-qr-code/?size=220x220&data=BIN-EV12-SMART-BIN-A01';
      if (testQrLabel) testQrLabel.textContent = 'Payload: BIN-EV12-SMART-BIN-A01';
    });

    btnTestQrVoucher?.addEventListener('click', () => {
      btnTestQrVoucher.classList.add('active');
      btnTestQrBin?.classList.remove('active');
      if (testQrImg) testQrImg.src = 'https://api.qrserver.com/v1/create-qr-code/?size=220x220&data=AGR-JG-5-A93F-SEC';
      if (testQrLabel) testQrLabel.textContent = 'Payload: AGR-JG-5-A93F-SEC';
    });

    // Bokashi Guide
    document.getElementById('btn-open-accepted-guide')?.addEventListener('click', () => {
      alert('Bokashi Guide 101: Bokashi utilizes anaerobic fermentation. Always press food down firmly and ensure the lid seals with a solid click. Empty the liquid Bokashi tea every 3-5 days to feed your house plants!');
    });
  },

  // -----------------------------------------------------------------
  // Merchant Controls
  // -----------------------------------------------------------------
  bindMerchantControls() {
    const btnScanDemo = document.getElementById('btn-merchant-scan-demo');
    btnScanDemo?.addEventListener('click', () => {
      SoundEffects.playScanBeep();
      setTimeout(() => {
        SoundEffects.playSuccessChime();
        const newRecord = {
          time: 'Just now',
          user: `${AgriState.profile.unit} (${AgriState.profile.nickname})`,
          value: 5.00,
          token: `AGR-JG-5-${Math.floor(1000 + Math.random() * 9000)}`
        };
        AgriState.merchantRedemptions.unshift(newRecord);
        alert(`✓ Voucher Verified: RM 5.00 applied for ${newRecord.user}. Cryptographic HMAC valid.`);
        this.renderMerchantView();
      }, 700);
    });
  },

  // -----------------------------------------------------------------
  // Operator Controls
  // -----------------------------------------------------------------
  bindOperatorControls() {
    // Operator Sub-tabs
    const opTabs = document.querySelectorAll('.op-tab-btn');
    opTabs.forEach(btn => {
      btn.addEventListener('click', () => {
        opTabs.forEach(b => b.classList.remove('active'));
        btn.classList.add('active');

        document.querySelectorAll('.operator-tab-viewport .op-tab-page').forEach(p => {
          p.classList.remove('active-op-page');
        });

        const target = btn.dataset.optab;
        document.getElementById(target)?.classList.add('active-op-page');
        SoundEffects.playUnlockClick();
      });
    });

    // Emergency Remote Unlock
    document.getElementById('btn-remote-unlock-modal')?.addEventListener('click', () => {
      if (confirm('Execute Remote Maintenance Unlock for Bin A01? (Audit logged)')) {
        SoundEffects.playUnlockClick();
        alert('Bin A01 solenoid unlocked remotely via MQTT over TLS. Auto-relocking in 60s.');
      }
    });
  },

  // -----------------------------------------------------------------
  // Comprehensive Render Functions
  // -----------------------------------------------------------------
  renderAllViews() {
    this.renderHeader();
    this.renderHomeTab();
    this.renderRewardsTab();
    this.renderCommunityTab();
    this.renderProfileTab();
    this.renderMerchantView();
    this.renderOperatorView();
  },

  renderHeader() {
    document.getElementById('res-nickname').textContent = AgriState.profile.nickname;
    document.getElementById('res-township-tag').innerHTML = `<span class="dot-green"></span> ${AgriState.profile.township.split('(')[0]} · ${AgriState.profile.unit}`;
    
    // Unread inbox notifications badge
    const unreadCount = AgriState.notifications.filter(n => n.unread).length;
    const badge = document.getElementById('inbox-badge-count');
    if (badge) {
      badge.textContent = unreadCount;
      badge.style.display = unreadCount > 0 ? 'flex' : 'none';
    }

    const initials = AgriState.profile.nickname.split(' ').map(n => n[0]).join('').substring(0, 2).toUpperCase();
    document.getElementById('res-avatar').textContent = initials;
    document.getElementById('prof-user-nickname').textContent = AgriState.profile.nickname;
  },

  renderHomeTab() {
    // Points
    document.getElementById('res-points-display').textContent = AgriState.profile.points.toLocaleString();
    const rmVal = (AgriState.profile.points / 200).toFixed(2);
    document.querySelector('.points-rm-tag').textContent = `≈ RM ${rmVal}`;

    // Streak & kg
    document.getElementById('res-streak-weeks').textContent = AgriState.profile.streakWeeks;
    document.getElementById('res-kg-diverted').textContent = `${AgriState.profile.totalKgDiverted} kg`;

    // CO2 Avoided (IPCC calculation: 1 kg diverted food waste = 2.5 kg CO2e)
    const co2 = (AgriState.profile.totalKgDiverted * AgriState.profile.co2Factor).toFixed(1);
    document.getElementById('res-co2-avoided').textContent = `${co2} kg`;

    // Nearest Bin A01
    const binA = AgriState.bins[0];
    document.getElementById('nearest-bin-fill-pct').textContent = `${binA.fill_pct}%`;
    document.getElementById('nearest-bin-fill-bar').style.width = `${binA.fill_pct}%`;
    document.getElementById('nearest-bin-temp').textContent = `${binA.temp_c}°C`;

    // Community Compost Progress
    const pct = Math.min(100, Math.round((AgriState.community.currentCompostKg / AgriState.community.targetCompostKg) * 100));
    document.getElementById('compost-progress-text').textContent = `${AgriState.community.currentCompostKg} / ${AgriState.community.targetCompostKg} kg`;
    document.getElementById('compost-progress-bar-fill').style.width = `${pct}%`;
  },

  renderRewardsTab() {
    document.getElementById('rewards-tab-points').textContent = AgriState.profile.points.toLocaleString();
    document.getElementById('my-vouchers-count').textContent = AgriState.myVouchers.filter(v => v.status === 'active').length;

    // Render Voucher Catalogue
    const catalogContainer = document.getElementById('vouchers-catalog-list');
    if (catalogContainer) {
      catalogContainer.innerHTML = AgriState.voucherCatalog.map(item => {
        const canAfford = AgriState.profile.points >= item.costPts;
        return `
          <div class="voucher-card">
            <div class="voucher-left">
              <div class="merchant-logo-box">${item.icon}</div>
              <div>
                <div class="voucher-title">${item.title}</div>
                <div class="voucher-merchant">${item.merchant} · Valid ${item.expiryDays}d</div>
                <div class="voucher-cost-tag">🪙 ${item.costPts} pts</div>
              </div>
            </div>
            <button class="redeem-mini-btn" ${!canAfford ? 'disabled' : ''} onclick="window.handleRedeemVoucher('${item.id}')">
              ${canAfford ? 'Redeem' : 'Need pts'}
            </button>
          </div>
        `;
      }).join('');
    }

    // Render Active Vouchers
    const myVouchersContainer = document.getElementById('my-vouchers-container');
    if (myVouchersContainer) {
      if (AgriState.myVouchers.length === 0) {
        myVouchersContainer.innerHTML = '<p class="text-muted" style="font-size:0.8rem; padding:10px;">No active vouchers yet. Redeem from the catalogue!</p>';
      } else {
        myVouchersContainer.innerHTML = AgriState.myVouchers.map(v => `
          <div class="my-voucher-active-card">
            <div>
              <strong style="color:#fff; font-size:0.85rem;">${v.merchant}</strong>
              <div style="font-size:0.75rem; color:#86efac;">${v.title}</div>
              <div style="font-size:0.65rem; color:#94a3b8;">Expires: ${v.expiryDate}</div>
            </div>
            <button class="view-qr-btn" onclick="window.handleViewVoucherQR('${v.id}')">
              Show QR Pass
            </button>
          </div>
        `).join('');
      }
    }
  },

  renderCommunityTab() {
    const list = document.getElementById('block-leaderboard-list');
    if (list) {
      const rankClasses = ['gold', 'silver', 'bronze'];
      list.innerHTML = AgriState.community.blocks.map((blk, idx) => `
        <div class="leader-item ${blk.isUser ? 'my-block' : ''}">
          <div class="leader-rank-col">
            <span class="rank-number ${rankClasses[idx] || ''}">#${blk.rank}</span>
            <span class="block-title">${blk.name}</span>
          </div>
          <span class="block-stat">${blk.kg} kg diverted</span>
        </div>
      `).join('');
    }
  },

  renderProfileTab() {
    document.getElementById('prof-user-nickname').textContent = AgriState.profile.nickname;
  },

  renderInbox() {
    const container = document.getElementById('inbox-messages-container');
    if (container) {
      container.innerHTML = AgriState.notifications.map(n => `
        <div class="inbox-item ${n.unread ? 'unread' : ''}">
          <div style="font-size:1.1rem;">${n.type === 'deposit' ? '🌱' : (n.type === 'alert' ? '⚠️' : '🎟️')}</div>
          <div>
            <div class="inbox-msg-title">${n.title}</div>
            <div class="inbox-msg-body">${n.body}</div>
            <div class="inbox-msg-time">${n.time}</div>
          </div>
        </div>
      `).join('');
    }
  },

  renderDepositHistory() {
    const container = document.getElementById('deposit-history-container');
    if (container) {
      container.innerHTML = AgriState.deposits.map(d => `
        <div style="display:flex; gap:12px; align-items:center; background:rgba(0,0,0,0.3); padding:10px 12px; border-radius:8px; margin-bottom:8px;">
          <img src="${d.thumb}" style="width:48px; height:48px; border-radius:6px; object-fit:cover;">
          <div style="flex:1;">
            <div style="display:flex; justify-content:space-between;">
              <strong style="font-size:0.82rem; color:#fff;">Bin ${d.binId} · ${d.weightKg} kg</strong>
              <span style="font-size:0.75rem; font-weight:700; color:#fbbf24;">+${d.points} pts</span>
            </div>
            <div style="font-size:0.7rem; color:${d.clean ? '#86efac' : '#fca5a5'};">${d.verdict}</div>
            <div style="font-size:0.65rem; color:#64748b;">${d.date}</div>
          </div>
        </div>
      `).join('');
    }
  },

  renderMerchantView() {
    const list = document.getElementById('merchant-redemption-list');
    if (list) {
      list.innerHTML = AgriState.merchantRedemptions.map(r => `
        <div class="redemption-item">
          <div>
            <div class="redemption-user">${r.user}</div>
            <div class="redemption-meta">${r.time} · Token: ${r.token}</div>
          </div>
          <div class="redemption-val">-RM ${r.value.toFixed(2)}</div>
        </div>
      `).join('');
    }
  },

  renderOperatorView() {
    // 1. Fleet Bins
    const fleetList = document.getElementById('operator-fleet-list');
    if (fleetList) {
      fleetList.innerHTML = AgriState.bins.map(bin => `
        <div class="fleet-card">
          <div class="fleet-card-header">
            <div>
              <span class="fleet-bin-name">Smart Bin ${bin.id}</span>
              <div style="font-size:0.68rem; color:#94a3b8;">${bin.name}</div>
            </div>
            <span class="fleet-status-pill online">● ONLINE (MQTT)</span>
          </div>
          <div class="fleet-metrics-row">
            <div class="f-metric">
              <span>WEIGHT</span>
              <strong>${(bin.weight_g / 1000).toFixed(2)} kg</strong>
            </div>
            <div class="f-metric">
              <span>FILL</span>
              <strong>${bin.fill_pct}%</strong>
            </div>
            <div class="f-metric">
              <span>TEMP</span>
              <strong>${bin.temp_c}°C</strong>
            </div>
            <div class="f-metric">
              <span>LOCK</span>
              <strong style="color:#22c55e;">${bin.lock.toUpperCase()}</strong>
            </div>
          </div>
          <div class="fleet-action-row">
            <button class="op-action-btn-sm" onclick="alert('Sent ping to ESP32: RSSI ${bin.rssi} dBm, Wi-Fi OK')">Ping ESP32</button>
            <button class="op-action-btn-sm" onclick="window.handleRemoteUnlockBin('${bin.id}')">Unlock Lid</button>
          </div>
        </div>
      `).join('');
    }

    // 2. Tasks
    const taskCount = document.getElementById('op-task-count');
    if (taskCount) taskCount.textContent = AgriState.operatorTasks.length;
    const taskList = document.getElementById('operator-tasks-list');
    if (taskList) {
      taskList.innerHTML = AgriState.operatorTasks.map((t, idx) => `
        <div class="task-card">
          <div class="task-info">
            <strong>${t.title} [Bin ${t.binId}]</strong>
            <span>${t.desc}</span>
          </div>
          <button class="task-btn" onclick="window.handleCompleteTask(${idx})">Done</button>
        </div>
      `).join('');
    }

    // 3. Batches
    const batchList = document.getElementById('operator-batches-list');
    if (batchList) {
      batchList.innerHTML = AgriState.batches.map(b => {
        const pct = Math.round((b.dayCurrent / b.dayTotal) * 100);
        return `
          <div class="batch-card">
            <div class="batch-header">
              <span>${b.id} (${b.binSource})</span>
              <span style="color:#a3e635;">Day ${b.dayCurrent} of ${b.dayTotal}</span>
            </div>
            <div class="batch-progress-bar">
              <div class="batch-progress-fill" style="width:${pct}%;"></div>
            </div>
            <div class="batch-footer">
              <span>Sealed: ${b.sealedDate}</span>
              <span>Status: ${b.status}</span>
            </div>
          </div>
        `;
      }).join('');
    }

    // 4. Review Queue
    const reviewCount = document.getElementById('op-review-count');
    if (reviewCount) reviewCount.textContent = AgriState.reviewQueue.length;
    const queueList = document.getElementById('operator-queue-list');
    if (queueList) {
      if (AgriState.reviewQueue.length === 0) {
        queueList.innerHTML = '<p style="font-size:0.75rem; color:#94a3b8; padding:10px;">Queue is clear! All deposits verified.</p>';
      } else {
        queueList.innerHTML = AgriState.reviewQueue.map((item, idx) => `
          <div class="queue-card">
            <div class="queue-thumb-row">
              <img src="${item.img}" class="queue-thumb">
              <div class="queue-meta">
                <strong>${item.depositId} · ${item.user}</strong>
                <span>${item.reason}</span>
                <span style="font-size:0.65rem; color:#64748b;">Confidence: ${item.confidence}</span>
              </div>
            </div>
            <div class="queue-btn-row">
              <button class="queue-btn approve" onclick="window.handleApproveDispute(${idx})">✓ Override & Award Points</button>
              <button class="queue-btn reject" onclick="window.handleRejectDispute(${idx})">✕ Uphold Flag</button>
            </div>
          </div>
        `).join('');
      }
    }
  }
};

// ===================================================================
// 4. GLOBAL WINDOW DISPATCHERS (For inline HTML event bindings)
// ===================================================================

window.handleRedeemVoucher = function(catalogId) {
  AppUI.redeemVoucher(catalogId);
};

window.handleViewVoucherQR = function(voucherId) {
  const v = AgriState.myVouchers.find(item => item.id === voucherId);
  if (v) AppUI.openVoucherPassModal(v);
};

window.handleSaveOnboarding = function() {
  const township = document.getElementById('onboard-township').value;
  const block = document.getElementById('onboard-block').value;
  const unit = document.getElementById('onboard-unit').value;
  const nickname = document.getElementById('onboard-nickname').value;

  AgriState.profile.township = township;
  AgriState.profile.block = block;
  AgriState.profile.unit = unit;
  AgriState.profile.nickname = nickname;

  AppUI.renderAllViews();
  document.getElementById('modal-onboarding').classList.remove('open');
  SoundEffects.playSuccessChime();
};

window.handleSubmitReport = function() {
  const binId = document.getElementById('report-bin-id').value;
  const category = document.getElementById('report-category').value;
  const notes = document.getElementById('report-notes').value;

  // Push to operator tasks
  AgriState.operatorTasks.unshift({
    id: `T-${Date.now().toString().slice(-3)}`,
    binId: binId,
    title: `Resident Report: ${category}`,
    desc: notes || 'Resident alerted issue via in-app problem report.',
    priority: 'high'
  });

  AppUI.renderOperatorView();
  document.getElementById('modal-report').classList.remove('open');
  SoundEffects.playScanBeep();
  alert('Thank you! Service ticket dispatched to Sime Darby on-site maintenance crew.');
};

window.handleCompleteTask = function(index) {
  AgriState.operatorTasks.splice(index, 1);
  SoundEffects.playSuccessChime();
  AppUI.renderOperatorView();
};

window.handleRemoteUnlockBin = function(binId) {
  if (confirm(`Send MQTT unlock command to Bin ${binId}?`)) {
    SoundEffects.playUnlockClick();
    alert(`Bin ${binId} lid unlatched.`);
  }
};

window.handleApproveDispute = function(index) {
  const item = AgriState.reviewQueue[index];
  AgriState.reviewQueue.splice(index, 1);
  AgriState.profile.points += 75; // Grant points
  SoundEffects.playSuccessChime();
  alert(`Deposit ${item.depositId} approved by operator. Points credited to resident.`);
  AppUI.renderAllViews();
};

window.handleRejectDispute = function(index) {
  const item = AgriState.reviewQueue[index];
  AgriState.reviewQueue.splice(index, 1);
  SoundEffects.playAlertWarning();
  alert(`Deposit ${item.depositId} flag confirmed. Educational notice sent to user.`);
  AppUI.renderOperatorView();
};

window.handleLogCompost = function() {
  const kg = parseFloat(document.getElementById('input-compost-kg').value) || 20;
  const loc = document.getElementById('select-compost-loc').value;
  const note = document.getElementById('input-compost-note').value;

  AgriState.community.currentCompostKg += kg;

  AgriState.notifications.unshift({
    id: `N-${Date.now()}`,
    type: 'deposit',
    unread: true,
    title: `🌸 Community Compost Milestone!`,
    body: `${kg} kg of fermented Bokashi compost returned to ${loc}!`,
    time: 'Just now'
  });

  SoundEffects.playSuccessChime();
  alert(`Published milestone! +${kg} kg added to resident community progress meter.`);
  AppUI.renderAllViews();
};

// ===================================================================
// 5. APPLICATION BOOTSTRAP
// ===================================================================

document.addEventListener('DOMContentLoaded', () => {
  AppUI.init();
});
