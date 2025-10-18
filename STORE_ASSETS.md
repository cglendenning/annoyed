# App Store Assets Guide

Complete checklist for submitting Annoyed to iOS App Store and Google Play Store.

## Required Assets

### 1. App Icon

**Dimensions:** 1024x1024px (PNG, no transparency)

**Design:** 
- Simple ⚡️ bolt icon + small wave glyph
- Calm teal/ink background (avoid red/anger colors)
- Use: `#2D9CDB` (brand color)

**Tools:**
- Design in Figma or Sketch
- Generate iOS assets: [appicon.co](https://appicon.co)
- Generate Android assets: Android Studio → Image Asset Studio

**Location:**
- iOS: `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
- Android: `android/app/src/main/res/mipmap-*/`

---

### 2. Screenshots

**Required: 6 screenshots minimum**

#### Screenshot 1: Capture (Home)
- Show Hold-to-Record button
- Display: "Annoyed today: 2"
- Caption: **"Capture annoyances in seconds."**

#### Screenshot 2: Transcribing → Categorized
- Show transcript with category chip
- Display: [Boundaries] tag
- Caption: **"Auto-transcribed. Smartly labeled."**

#### Screenshot 3: Daily Coach Prompt
- Show: "Good moment for a suggestion?"
- Buttons: "Not now" / "Yes"
- Caption: **"We ask when you're ready."**

#### Screenshot 4: Suggestion Card
- Show full suggestion text
- Display: "5 days" badge
- Show: HELL YES / Meh buttons
- Caption: **"One precise behavior, not a lecture."**

#### Screenshot 5: Profile / Metrics
- Show: Top Pattern card
- Display: Category distribution chart
- Show: Key metrics (Annoyance Rate, Follow-Through)
- Caption: **"Watch annoyances drop and patterns shift."**

#### Screenshot 6: Settings (Preferred Hours)
- Show: Preferred Hours settings
- Display: "10:00 - 19:00"
- Show: "Respect Do Not Disturb" toggle
- Caption: **"You control when we nudge."**

**Dimensions:**
- iPhone 15 Pro Max: 1290 x 2796 px (6.7")
- iPhone 8 Plus: 1242 x 2208 px (5.5")
- iPad Pro (3rd gen): 2048 x 2732 px (12.9")
- Android Phone: 1080 x 1920 px minimum
- Android Tablet: 1920 x 1200 px minimum

**Tips:**
- Use device frames: [screenshots.pro](https://screenshots.pro)
- Add staging data (realistic but clean examples)
- Keep UI clean, no personal info
- Use consistent lighting/theme

---

### 3. App Store Copy

#### Name
```
Annoyed
```

#### Tagline (iOS Subtitle)
```
Annoyed → Aligned.
```

#### Short Description (Google Play, 80 chars)
```
Vent fast. Get your pattern after 3 entries. Then keep upgrading.
```

#### Long Description (Apple, 4000 chars; Google, 4000 chars)

```
Two modes. One mission: upgrade what annoys you.

CAPTURE MODE
Something sets you off? Open Annoyed and hold to record. Your voice note is transcribed on-device—audio never leaves your phone—and categorized into one of five patterns: Boundaries, Environment, Systems Debt, Communication, or Energy.

No journaling tax. No long forms. Capture takes seconds.

COACH MODE
Once a day, at a varying time inside the hours you choose, Annoyed checks in: "Good moment for a suggestion?" If it isn't, tap "Not now." If it is, you receive exactly one concise suggestion tailored to your recent patterns.

Sometimes it's a mindset reframe that creates an immediate shift. Other times it's a specific daily behavior you can complete in under thirty minutes. Tap "HELL YES!" or "Meh" to train what you get next.

MAGIC AFTER 3
Within three entries, Annoyed shows you a simple pattern snapshot so you can see what's driving the friction. From there, the emphasis is on increasing suggestion quality.

PRIVACY BY DEFAULT
• Audio transcribed on-device only (iOS Speech / Android SpeechRecognizer)
• Client-side PII redaction before any network call
• No audio upload. Ever.
• Delete all data anytime.

WHY IT WORKS
• Frictionless capture preserves the truth of the moment
• Coaching is deferred until you're ready to act—higher follow-through
• One action only. No overwhelm.
• Pattern feedback reframes growth positively

PRO FEATURES
• 90-second recordings
• Deeper pattern insights
• Custom coach hours
• Higher suggestion frequency
• Priority support

Start free. Upgrade anytime.

Annoyed → Aligned.
```

---

### 4. Keywords (iOS, 100 chars max)

```
annoyed,frustration,habit,boundaries,focus,calm,journal,vent,self-coaching,patterns
```

---

### 5. Privacy Labels

#### Apple App Store

**Data Collected:**
- **Audio** (On-device only, not uploaded)
- **User Content** (Transcripts, redacted)
- **Usage Data** (Analytics, no identifiers)

**Data Not Tracked:**
- No cross-app tracking
- No advertising tracking

**Data Deletion:**
- User can delete all data via Settings

#### Google Play Data Safety

**Data Shared:**
- Transcripts (redacted text only)
- Analytics (app activity, diagnostics)

**Data Security:**
- Data encrypted in transit
- User can request deletion

---

### 6. App Preview Video (Optional but Recommended)

**Length:** 30-45 seconds

**Script:**
```
[0-5s]   Open app → Hold to record
[5-10s]  "Every time I start coding, I get pinged…"
[10-15s] Release → Transcribing → [Boundaries]
[15-20s] Notification: "Good moment for a suggestion?"
[20-30s] Show suggestion card + HELL YES button
[30-35s] Profile screen with pattern shift
[35-40s] Text: "Annoyed → Aligned."
```

**Tools:**
- Record with QuickTime Player (Mac)
- Edit with iMovie or Final Cut Pro
- Export: H.264, 30fps, high quality

---

### 7. Developer Info

**Support URL:** [Your website or support email]

**Privacy Policy URL:** [Required - create one at privacypolicies.com]

**Terms of Service URL:** [Optional but recommended]

**Copyright:** © 2025 Craig Glendenning

---

## Submission Checklist

### Pre-Submission

- [ ] Test on physical devices (iOS + Android)
- [ ] Verify all features work without crashes
- [ ] Test paywall flow end-to-end
- [ ] Test permissions (mic, notifications)
- [ ] Check for console errors/warnings
- [ ] Verify analytics events fire correctly
- [ ] Test on slow network (3G simulation)

### iOS App Store

- [ ] App icon (1024x1024)
- [ ] 6 screenshots (iPhone 6.7" + 5.5")
- [ ] App preview video (optional)
- [ ] Description + keywords
- [ ] Privacy labels configured
- [ ] Build uploaded via Xcode
- [ ] TestFlight tested
- [ ] Age rating set (4+)
- [ ] Category: Productivity or Health & Fitness
- [ ] Pricing: Free with IAP
- [ ] Support URL + Privacy Policy URL

### Google Play Store

- [ ] Feature graphic (1024x500)
- [ ] App icon (512x512)
- [ ] 6 screenshots (phone + tablet)
- [ ] Promo video (YouTube link, optional)
- [ ] Description (short + long)
- [ ] Data safety form completed
- [ ] APK/AAB uploaded
- [ ] Content rating questionnaire
- [ ] Category: Productivity
- [ ] Pricing: Free with IAP
- [ ] Store listing reviewed

---

## Post-Launch

1. **Monitor Reviews**
   - Respond to reviews within 24h
   - Track common feedback themes

2. **Analytics**
   - Watch retention (D1, D7, D30)
   - Track conversion to paid
   - Monitor LLM costs per user

3. **Iterate**
   - A/B test paywall messaging
   - Refine suggestion prompts based on resonance
   - Add requested features

---

## Resources

- [iOS App Store Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Google Play Store Guidelines](https://play.google.com/console/about/guides/policyadd/)
- [App Store Screenshots Sizes](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications)
- [Privacy Policy Generator](https://www.privacypolicies.com/)
- [Terms Generator](https://www.termsfeed.com/)

---

**Ready to ship!** 🚀








