# MINI-PROJECT SHORT TECHNICAL REPORT

**Course:** Cross-Platform Mobile App Development (VKU)  
**Mini-Project Title:** Mini-Project 3 — OCR Expense Tracker & Receipt Parser  
**App Name:** ReceiptWise  
**Team / Student Name:** Pham Ngoc Duc  
**Student ID:** 23IT059  
**Class:** 23JIT  
**Submission Date:** 10/10/2026

---

## 1. GENERAL INFORMATION & DELIVERABLE LINKS

* **Team Members:**
  1. **Pham Ngoc Duc** — Student ID: **23IT059** — Class: **23JIT** — Role: **Solo Developer** — Contribution: **100%**
* **🔗 Live Demo URL:** Not published yet. Add the Cloudflare Pages URL after deployment.
* **💻 GitHub Repository:** Not provided. Add the repository URL if the project is pushed to GitHub.
* **📦 Android APK:** Build locally using the instructions in the project README. Add a shareable download link after uploading the APK.
* **🎥 Video Demo (Optional):** Not available yet.

---

## 2. FEATURE IMPLEMENTATION CHECKLIST

| # | Required Feature | Status | Implementation Details & Acceptance Level |
|:---:|---|:---:|---|
| 1 | Personal finance and expense tracking | ✅ Implemented | Add expenses manually, search by merchant/category, filter by category, edit transaction dates, and delete records. Amounts are displayed in VND. |
| 2 | On-device receipt text recognition | ✅ Implemented | Android receipt images are processed with Google ML Kit Text Recognition. OCR is performed on-device; the web build does not include receipt OCR. |
| 3 | Receipt parsing and review | ✅ Implemented | Regex and text heuristics suggest merchant, transaction date, total, and category. The user can review and correct extracted values before saving. |
| 4 | Offline local persistence | ✅ Implemented | Android uses SQLite for expenses and monthly budgets. Web demo data is stored in browser local storage. |
| 5 | Monthly category budgets | ✅ Implemented | Set category spending limits and see progress and over-budget warnings. |
| 6 | Interactive spending charts | ✅ Implemented | CustomPainter renders an animated, tappable category donut and animated weekly spending bars. |
| 7 | Browser demonstration | 🟡 Ready to build/deploy | Flutter web target and browser storage fallback are present. Publish `build/web` to a static host to create the live demo URL. OCR is Android-only. |
| 8 | Installable Android APK | 🟡 Build pending final verification | Android release build is configured for local testing. An R8 missing optional ML Kit language-class issue was addressed with ProGuard rules; the release build still needs to be rerun successfully on the development PC. |

---

## 3. TECHNICAL ARCHITECTURE & PROJECT STRUCTURE

The project uses Flutter and Dart for the user interface and app logic. `main.dart` manages the dashboard and expense-entry flows. Expense and budget data are represented by model classes. Service classes isolate receipt OCR, parsing, and storage. Platform-specific conditional imports use SQLite on Android and browser local storage on web. The charts are drawn with Flutter's `CustomPainter` and animated from the UI.

```text
lib/
  main.dart
  models/
    expense.dart
    category_budget.dart
  services/
    receipt_ocr.dart
    receipt_ocr_web.dart
    receipt_parser.dart
    expense_database.dart
    expense_database_web.dart
  widgets/
    spending_painters.dart
android/
  app/                 Android manifest, Gradle and ProGuard configuration
web/                   Flutter web scaffold
test/                  Flutter test scaffold
```

**State and persistence flow:** The screen loads expenses and budgets through the selected platform storage service. User actions update the stored data and refresh the dashboard. Android receipt scanning sends the selected image through ML Kit, then passes recognized text to the parser. Parsed fields populate a review form; only after the user confirms are they stored as an expense.

**Exception handling:** OCR and image selection can fail or be cancelled, so the user should be able to retry or enter an expense manually. Parser output is treated as a suggestion because receipt layouts and date/amount formats vary. The web OCR fallback reports that scanning requires Android rather than pretending to scan.

---

## 4. EMPIRICAL EVIDENCE & SCREENSHOTS

Add 3–4 screenshots captured from the running app before submission. Suggested evidence:

1. **Dashboard:** VND monthly summary, category donut, and weekly chart.
2. **Receipt scan/review:** Recognized receipt fields before saving.
3. **Budget management:** Category budget and spending progress or warning.
4. **Expense list/form:** Search/filter controls and a saved VND transaction.

Suggested file locations (create the `screenshots` folder and add the image files):

```text
screenshots/dashboard.png
screenshots/receipt_review.png
screenshots/budgets.png
screenshots/expense_list.png
```

Replace this note with annotated images or links when captured. No screenshots are embedded yet.

---

## 5. TECHNICAL CHALLENGES & RESOLUTIONS

1. **Android development environment and native build dependencies:** Initial device builds required configuring Flutter, Android command-line tools, SDK licenses, and NDK components. The project was then run on a physical Android device. A later release attempt also exhausted disk space while downloading Flutter Android artifacts; building only the target ARM64 architecture reduces unnecessary downloads.
2. **R8 and optional ML Kit language recognizers:** The release shrinker reported missing Chinese, Japanese, Korean, and Devanagari recognizer classes referenced by the ML Kit plugin, although the app uses the Latin recognizer. ProGuard `-dontwarn` rules were added for those optional packages. The release APK must be rebuilt to confirm the fix on the development machine.

---

## Final Submission Notes

Before submitting, build and install the ARM64 APK, test receipt scanning and manual entry on the phone, capture the screenshots above, and replace the demo/repository/APK placeholders with real links. The current debug signing key is for demonstration and direct installation; use a private release keystore for public distribution.
