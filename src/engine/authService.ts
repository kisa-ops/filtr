// =============================================================================
// authService.ts — Production-Ready Cryptographic Admin Authentication Service
// =============================================================================
// Uses Web Crypto API PBKDF2 with SHA-256 (100,000 iterations & random salting).
// Includes rate-limiting (5 failed attempts -> 5 min lockout) & session expiry.
// =============================================================================

const AUTH_STORAGE_KEY = 'filtr_admin_auth';
const SESSION_STORAGE_KEY = 'filtr_admin_session';
const LOCKOUT_STORAGE_KEY = 'filtr_auth_lockout';

const MAX_FAILED_ATTEMPTS = 5;
const LOCKOUT_DURATION_MS = 5 * 60 * 1000; // 5 minutes
const SESSION_DURATION_MS = 2 * 60 * 60 * 1000; // 2 hours
const PBKDF2_ITERATIONS = 100000;

interface StoredAuth {
  salt: string; // hex encoded 16 bytes
  hash: string; // hex encoded 32 bytes
  isConfigured: boolean;
  createdAt: number;
}

interface StoredLockout {
  failedAttempts: number;
  lockoutUntil: number; // timestamp ms
}

interface StoredSession {
  token: string;
  expiresAt: number;
}

// Convert ArrayBuffer to Hex String
function bufToHex(buffer: ArrayBuffer): string {
  return Array.from(new Uint8Array(buffer))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');
}

// Convert Hex String to Uint8Array
function hexToBuf(hex: string): Uint8Array {
  const bytes = new Uint8Array(hex.length / 2);
  for (let i = 0; i < hex.length; i += 2) {
    bytes[i / 2] = parseInt(hex.substring(i, i + 2), 16);
  }
  return bytes;
}

// Cryptographic password derivation with PBKDF2
async function deriveHash(password: string, saltBytes: Uint8Array): Promise<string> {
  const enc = new TextEncoder();
  const keyMaterial = await window.crypto.subtle.importKey(
    'raw',
    enc.encode(password) as unknown as BufferSource,
    'PBKDF2',
    false,
    ['deriveBits']
  );

  const derivedBits = await window.crypto.subtle.deriveBits(
    {
      name: 'PBKDF2',
      salt: saltBytes as unknown as BufferSource,
      iterations: PBKDF2_ITERATIONS,
      hash: 'SHA-256'
    },
    keyMaterial,
    256 // 32 bytes
  );

  return bufToHex(derivedBits);
}

// Lockout helpers
function getLockoutData(): StoredLockout {
  try {
    const raw = localStorage.getItem(LOCKOUT_STORAGE_KEY);
    if (!raw) return { failedAttempts: 0, lockoutUntil: 0 };
    return JSON.parse(raw);
  } catch {
    return { failedAttempts: 0, lockoutUntil: 0 };
  }
}

function recordFailedAttempt(): { isLocked: boolean; remainingSeconds: number; attemptsLeft: number } {
  const data = getLockoutData();
  const now = Date.now();
  data.failedAttempts += 1;

  if (data.failedAttempts >= MAX_FAILED_ATTEMPTS) {
    data.lockoutUntil = now + LOCKOUT_DURATION_MS;
    localStorage.setItem(LOCKOUT_STORAGE_KEY, JSON.stringify(data));
    return { isLocked: true, remainingSeconds: Math.ceil(LOCKOUT_DURATION_MS / 1000), attemptsLeft: 0 };
  }

  localStorage.setItem(LOCKOUT_STORAGE_KEY, JSON.stringify(data));
  return { 
    isLocked: false, 
    remainingSeconds: 0, 
    attemptsLeft: Math.max(0, MAX_FAILED_ATTEMPTS - data.failedAttempts) 
  };
}

function clearLockout(): void {
  localStorage.removeItem(LOCKOUT_STORAGE_KEY);
}

// =============================================================================
// Exported Public API
// =============================================================================

export const authService = {
  /**
   * Check if an admin passkey has been initialized.
   */
  isAuthConfigured(): boolean {
    try {
      const raw = localStorage.getItem(AUTH_STORAGE_KEY);
      if (!raw) return false;
      const data: StoredAuth = JSON.parse(raw);
      return Boolean(data.isConfigured && data.hash && data.salt);
    } catch {
      return false;
    }
  },

  /**
   * Check if login is currently locked out due to rate-limiting.
   */
  getLockoutStatus(): { isLocked: boolean; remainingSeconds: number } {
    const data = getLockoutData();
    const now = Date.now();
    if (data.lockoutUntil && data.lockoutUntil > now) {
      return {
        isLocked: true,
        remainingSeconds: Math.ceil((data.lockoutUntil - now) / 1000)
      };
    }
    // Lockout expired
    if (data.lockoutUntil > 0 && data.lockoutUntil <= now) {
      clearLockout();
    }
    return { isLocked: false, remainingSeconds: 0 };
  },

  /**
   * Initial setup for administrator password (requires minimum 8 characters).
   */
  async setupAdminPassword(password: string): Promise<{ success: boolean; error?: string }> {
    if (!password || password.trim().length < 8) {
      return { success: false, error: 'Password must be at least 8 characters long.' };
    }

    try {
      const saltBytes = new Uint8Array(16);
      window.crypto.getRandomValues(saltBytes);
      const hash = await deriveHash(password, saltBytes);

      const authData: StoredAuth = {
        salt: bufToHex(saltBytes.buffer),
        hash,
        isConfigured: true,
        createdAt: Date.now()
      };

      localStorage.setItem(AUTH_STORAGE_KEY, JSON.stringify(authData));
      clearLockout();
      this.createSession();
      return { success: true };
    } catch (e: any) {
      return { success: false, error: e.message || 'Failed to initialize password.' };
    }
  },

  /**
   * Verify password against stored PBKDF2 hash with rate-limiting.
   */
  async verifyAdminPassword(password: string): Promise<{
    success: boolean;
    error?: string;
    lockoutRemainingSeconds?: number;
    attemptsLeft?: number;
  }> {
    const lockout = this.getLockoutStatus();
    if (lockout.isLocked) {
      return {
        success: false,
        error: `Account locked due to too many failed attempts. Try again in ${lockout.remainingSeconds}s.`,
        lockoutRemainingSeconds: lockout.remainingSeconds
      };
    }

    try {
      const raw = localStorage.getItem(AUTH_STORAGE_KEY);
      if (!raw) {
        return { success: false, error: 'Admin authentication is not configured yet.' };
      }

      const data: StoredAuth = JSON.parse(raw);
      const saltBytes = hexToBuf(data.salt);
      const computedHash = await deriveHash(password, saltBytes);

      if (computedHash === data.hash) {
        clearLockout();
        this.createSession();
        return { success: true };
      } else {
        const failure = recordFailedAttempt();
        if (failure.isLocked) {
          return {
            success: false,
            error: `Maximum attempts exceeded. Account locked for ${failure.remainingSeconds}s.`,
            lockoutRemainingSeconds: failure.remainingSeconds,
            attemptsLeft: 0
          };
        }
        return {
          success: false,
          error: `Invalid admin passkey. (${failure.attemptsLeft} attempts remaining)`,
          attemptsLeft: failure.attemptsLeft
        };
      }
    } catch (e: any) {
      return { success: false, error: e.message || 'Authentication error.' };
    }
  },

  /**
   * Change current admin password.
   */
  async changeAdminPassword(oldPassword: string, newPassword: string): Promise<{ success: boolean; error?: string }> {
    if (!newPassword || newPassword.trim().length < 8) {
      return { success: false, error: 'New password must be at least 8 characters long.' };
    }

    // Verify old password first
    const verification = await this.verifyAdminPassword(oldPassword);
    if (!verification.success) {
      return { success: false, error: verification.error || 'Current passkey is incorrect.' };
    }

    // Derive new salt & hash
    try {
      const saltBytes = new Uint8Array(16);
      window.crypto.getRandomValues(saltBytes);
      const hash = await deriveHash(newPassword, saltBytes);

      const authData: StoredAuth = {
        salt: bufToHex(saltBytes.buffer),
        hash,
        isConfigured: true,
        createdAt: Date.now()
      };

      localStorage.setItem(AUTH_STORAGE_KEY, JSON.stringify(authData));
      this.createSession();
      return { success: true };
    } catch (e: any) {
      return { success: false, error: e.message || 'Failed to update password.' };
    }
  },

  /**
   * Check if current browser session is authenticated and active.
   */
  isAuthenticated(): boolean {
    try {
      const raw = sessionStorage.getItem(SESSION_STORAGE_KEY);
      if (!raw) return false;
      const session: StoredSession = JSON.parse(raw);
      if (Date.now() > session.expiresAt) {
        this.logout();
        return false;
      }
      return true;
    } catch {
      return false;
    }
  },

  /**
   * Create or refresh an active session.
   */
  createSession(): void {
    const sessionBytes = new Uint8Array(32);
    window.crypto.getRandomValues(sessionBytes);
    const session: StoredSession = {
      token: bufToHex(sessionBytes.buffer),
      expiresAt: Date.now() + SESSION_DURATION_MS
    };
    sessionStorage.setItem(SESSION_STORAGE_KEY, JSON.stringify(session));
  },

  /**
   * Terminate active session.
   */
  logout(): void {
    sessionStorage.removeItem(SESSION_STORAGE_KEY);
  }
};
