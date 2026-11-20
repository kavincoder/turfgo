// TurfGo — Owner Sign-Up Form
// Writes to Firestore `waitlist` collection (public create allowed in rules)
import { initializeApp } from 'https://www.gstatic.com/firebasejs/10.12.0/firebase-app.js';
import { getFirestore, doc, setDoc, serverTimestamp }
  from 'https://www.gstatic.com/firebasejs/10.12.0/firebase-firestore.js';

// ── Firebase config (public client identifiers — safe in frontend) ──────────
const firebaseConfig = {
  apiKey:            'AIzaSyD12oYjwyc4Av4V9KAI6fKQ5PCvTHuxjHA',
  authDomain:        'turfgo-3c555.firebaseapp.com',
  projectId:         'turfgo-3c555',
  storageBucket:     'turfgo-3c555.firebasestorage.app',
  messagingSenderId: '860814301168',
  appId:             '1:860814301168:web:bde0c3e1476c8f9a94af35',
};

const app = initializeApp(firebaseConfig);
const db  = getFirestore(app);

// ── DOM refs ─────────────────────────────────────────────────────────────────
const form       = document.getElementById('ownerForm');
const submitBtn  = document.getElementById('submitBtn');
const btnText    = document.getElementById('btnText');
const btnSpinner = document.getElementById('btnSpinner');
const formWrap   = document.getElementById('formWrap');
const successMsg = document.getElementById('successMsg');
const errorMsg   = document.getElementById('errorMsg');

// ── Validation helpers ────────────────────────────────────────────────────────
function showFieldError(inputId, msg) {
  const input = document.getElementById(inputId);
  const err   = document.getElementById(inputId + 'Error');
  input.classList.add('error');
  err.textContent = msg;
  err.classList.add('show');
}

function clearFieldError(inputId) {
  const input = document.getElementById(inputId);
  const err   = document.getElementById(inputId + 'Error');
  input.classList.remove('error');
  err.classList.remove('show');
}

// Clear errors on input
['name', 'turfName', 'phone'].forEach(id => {
  document.getElementById(id)?.addEventListener('input', () => clearFieldError(id));
});

function validate() {
  let valid = true;

  const name     = document.getElementById('name').value.trim();
  const turfName = document.getElementById('turfName').value.trim();
  const phone    = document.getElementById('phone').value.trim();

  if (!name) {
    showFieldError('name', 'Please enter your name.');
    valid = false;
  }
  if (!turfName) {
    showFieldError('turfName', 'Please enter your turf name.');
    valid = false;
  }
  // Indian mobile: 10 digits, starts 6–9
  if (!/^[6-9]\d{9}$/.test(phone)) {
    showFieldError('phone', 'Enter a valid 10-digit Indian mobile number.');
    valid = false;
  }

  return valid;
}

// ── Form submit ───────────────────────────────────────────────────────────────
form.addEventListener('submit', async (e) => {
  e.preventDefault();
  errorMsg.classList.remove('show');

  if (!validate()) return;

  // UI: loading state
  submitBtn.disabled  = true;
  btnText.style.display    = 'none';
  btnSpinner.style.display = 'block';

  const data = {
    name:      document.getElementById('name').value.trim(),
    turfName:  document.getElementById('turfName').value.trim(),
    city:      document.getElementById('city').value,
    phone:     document.getElementById('phone').value.trim(),
    source:    'website',
    createdAt: serverTimestamp(),
  };

  try {
    // Use phone as document ID — enforces 1 submission per phone at the Firestore rules level
    const phone = data.phone;
    await setDoc(doc(db, 'waitlist', phone), data);

    // Send email notification via Web3Forms (public access key — safe in frontend)
    fetch('https://api.web3forms.com/submit', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        access_key: 'd7179924-29e3-4451-9fca-2fc8d35582c2',
        subject:    '🏟️ New Turf Owner Sign-Up — TurfGo',
        from_name:  'TurfGo Waitlist',
        name:       data.name,
        turf:       data.turfName,
        city:       data.city,
        phone:      '+91' + data.phone,
        message:    `New owner sign-up:\n\nName: ${data.name}\nTurf: ${data.turfName}\nCity: ${data.city}\nPhone: +91${data.phone}`,
      }),
    }); // fire-and-forget — don't block UX on email delivery

    // Success
    formWrap.style.display  = 'none';
    successMsg.classList.add('show');
  } catch (err) {
    // Restore submit button
    submitBtn.disabled       = false;
    btnText.style.display    = 'flex';
    btnSpinner.style.display = 'none';

    errorMsg.textContent = err.code === 'permission-denied'
      ? 'This number is already registered. We\'ll be in touch soon!'
      : 'Something went wrong. Please try again or WhatsApp us at turfgo.official@gmail.com.';
    errorMsg.classList.add('show');
  }
});
