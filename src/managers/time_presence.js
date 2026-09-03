const fs = require('fs');
const path = require('path');

class TimePresenceManager {
  constructor(options = {}) {
    // Load defaults from config file if present
    try {
      const cfgPath = path.join(__dirname, '..', '..', 'config', 'time_presence.json');
      if (fs.existsSync(cfgPath)) {
        const cfg = JSON.parse(fs.readFileSync(cfgPath, 'utf-8'));
        this.shortAwayMinutes = cfg.shortAwayMinutes ?? 5;
        this.longAwayMinutes = cfg.longAwayMinutes ?? 120;
        this.sessionTimeoutMinutes = cfg.sessionTimeoutMinutes ?? 24 * 60;
      } else {
        this.shortAwayMinutes = options.shortAwayMinutes ?? 5;
        this.longAwayMinutes = options.longAwayMinutes ?? 120;
        this.sessionTimeoutMinutes = options.sessionTimeoutMinutes ?? 24 * 60;
      }
    } catch (e) {
      this.shortAwayMinutes = options.shortAwayMinutes ?? 5;
      this.longAwayMinutes = options.longAwayMinutes ?? 120;
      this.sessionTimeoutMinutes = options.sessionTimeoutMinutes ?? 24 * 60;
    }

    // sessionId -> { sessionStartAt, lastUserAt, lastAIAt }
    this.sessions = new Map();
  }

  _now() {
    return new Date();
  }

  startSession(sessionId) {
    const now = this._now();
    this.sessions.set(sessionId, {
      sessionStartAt: now,
      lastUserAt: null,
      lastAIAt: null
    });
  }

  touchUserMessage(sessionId) {
    const now = this._now();
    const s = this.sessions.get(sessionId) || {};
    s.lastUserAt = now;
    if (!s.sessionStartAt) s.sessionStartAt = now;
    this.sessions.set(sessionId, s);
  }

  touchAIResponse(sessionId) {
    const now = this._now();
    const s = this.sessions.get(sessionId) || {};
    s.lastAIAt = now;
    if (!s.sessionStartAt) s.sessionStartAt = now;
    this.sessions.set(sessionId, s);
  }

  getState(sessionId) {
    const now = this._now();
    const s = this.sessions.get(sessionId);
    if (!s) {
      return {
        sessionExists: false
      };
    }

    const lastInteraction = s.lastUserAt || s.lastAIAt || s.sessionStartAt;
    const minutesSinceLast = lastInteraction ? (now - lastInteraction) / 60000 : null;

    const isShortAway = minutesSinceLast !== null && minutesSinceLast >= this.shortAwayMinutes && minutesSinceLast < this.longAwayMinutes;
    const isLongAway = minutesSinceLast !== null && minutesSinceLast >= this.longAwayMinutes;
    const isTimedOut = minutesSinceLast !== null && minutesSinceLast >= this.sessionTimeoutMinutes;

    return {
      sessionExists: true,
      sessionStartAt: s.sessionStartAt,
      lastUserAt: s.lastUserAt,
      lastAIAt: s.lastAIAt,
      minutesSinceLast: minutesSinceLast,
      isShortAway,
      isLongAway,
      isTimedOut
    };
  }

  // Convenience: summary text for passing into LLM context
  summaryForPrompt(sessionId) {
    const state = this.getState(sessionId);
    if (!state.sessionExists) return '';

    if (state.isTimedOut) {
      return `User absent for a long time (>${this.sessionTimeoutMinutes} minutes). Treat this as a session restart.`;
    }

    if (state.isLongAway) {
      return `User was away for a long time (~${Math.round(state.minutesSinceLast)} minutes). Greet and offer a brief recap.`;
    }

    if (state.isShortAway) {
      return `User was away briefly (~${Math.round(state.minutesSinceLast)} minutes). You can resume naturally.`;
    }

    return `User active recently (${state.minutesSinceLast !== null ? Math.round(state.minutesSinceLast) : '0'} minutes ago).`;
  }

  // For tests or external control
  _forceSetSession(sessionId, data) {
    this.sessions.set(sessionId, data);
  }
}

module.exports = TimePresenceManager;
