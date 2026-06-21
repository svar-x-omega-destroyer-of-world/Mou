/// App-wide localisation (en / hi / bn).
///
/// Lightweight, dependency-free i18n: a single [AppStrings] value object holds
/// every user-facing string for the chosen language, and [AppText] publishes it
/// down the widget tree via an [InheritedWidget].  Changing the language at the
/// language-selection step rebuilds the whole subtree in the new language.
///
/// Backend-sourced text (the diagnosis explanation, disclaimer and next-step
/// office/form) is already localised server-side when the `language` field is
/// sent to /diagnose, so it is intentionally not duplicated here.
library;

import 'package:flutter/widgets.dart';

import '../api/mou_api.dart';

/// UI language codes supported by the app, in display order.
const List<String> kSupportedLanguages = ['en', 'hi', 'bn'];

/// Immutable bundle of every translatable UI string for a single language.
class AppStrings {
  final String lang; // 'en' | 'hi' | 'bn'
  const AppStrings(this.lang);

  /// Pick the variant for the current language, falling back to English.
  String _p(String en, String hi, String bn) =>
      lang == 'hi' ? hi : (lang == 'bn' ? bn : en);

  // ── Brand / welcome ────────────────────────────────────────────────────────
  String get appName => _p('Mou', 'मऊ', 'মৌ');
  String get welcomeTagline => _p(
        'Find out why your ration was denied — and what to do about it.',
        'जानिए आपका राशन क्यों रोका गया — और अब क्या करें।',
        'জানুন কেন আপনার রেশন আটকে গেছে — এবং এখন কী করবেন।',
      );
  String get welcomeBody => _p(
        'Mou compares your Aadhaar and ration card to spot the document mismatch that may be silently blocking your benefits.',
        'मऊ आपके आधार और राशन कार्ड की तुलना करके उस दस्तावेज़ी अंतर को पहचानता है जो चुपचाप आपके लाभ रोक सकता है।',
        'মৌ আপনার আধার ও রেশন কার্ড মিলিয়ে সেই নথির গরমিল খুঁজে বের করে যা নীরবে আপনার সুবিধা আটকে রাখতে পারে।',
      );
  String get getStarted => _p('Get Started', 'शुरू करें', 'শুরু করুন');

  // ── Language selection ──────────────────────────────────────────────────────
  String get chooseLanguage =>
      _p('Choose your language', 'अपनी भाषा चुनें', 'আপনার ভাষা বেছে নিন');
  String get chooseLanguageSub => _p(
        'The whole app — instructions and your result — will be shown in this language.',
        'पूरा ऐप — निर्देश और आपका परिणाम — इसी भाषा में दिखाया जाएगा।',
        'পুরো অ্যাপ — নির্দেশনা এবং আপনার ফলাফল — এই ভাষাতেই দেখানো হবে।',
      );
  String get continueLabel => _p('Continue', 'आगे बढ़ें', 'এগিয়ে যান');

  // ── App bar / step chrome ───────────────────────────────────────────────────
  String stepOf(int n, int total) =>
      _p('Step $n of $total', 'चरण $n / $total', 'ধাপ $n / $total');
  String get titleLanguage => _p('Language', 'भाषा', 'ভাষা');
  String get titleUpload =>
      _p('Upload Documents', 'दस्तावेज़ अपलोड करें', 'নথি আপলোড করুন');
  String get titleDetails => _p('Your Details', 'आपकी जानकारी', 'আপনার তথ্য');
  String get titleVerifying => _p('Verifying…', 'जाँच हो रही है…', 'যাচাই চলছে…');
  String get titleDiagnosis =>
      _p('Your Diagnosis', 'आपका निदान', 'আপনার নির্ণয়');

  // ── Upload step ─────────────────────────────────────────────────────────────
  String get uploadTitle => _p('Upload Your Documents',
      'अपने दस्तावेज़ अपलोड करें', 'আপনার নথি আপলোড করুন');
  String get uploadSubtitle => _p(
        'Take a clear photo of each card.\nBoth are needed to check for mismatches.',
        'हर कार्ड की साफ़ फ़ोटो लें।\nगड़बड़ी जाँचने के लिए दोनों ज़रूरी हैं।',
        'প্রতিটি কার্ডের স্পষ্ট ছবি তুলুন।\nগরমিল যাচাই করতে দুটোই প্রয়োজন।',
      );
  String get aadhaarCard => _p('Aadhaar Card', 'आधार कार्ड', 'আধার কার্ড');
  String get aadhaarCardSub => _p('Government ID / Aadhaar',
      'सरकारी पहचान / आधार', 'সরকারি পরিচয়পত্র / আধার');
  String get rationCard => _p('Ration Card', 'राशन कार्ड', 'রেশন কার্ড');
  String get rationCardSub => _p('PDS / ONORC ration card',
      'पीडीएस / वन-नेशन राशन कार्ड', 'পিডিএস / ওএনওআরসি রেশন কার্ড');
  String get uploadTip => _p(
        'Tip: Hold your card flat with good lighting. Avoid shadows and glare.',
        'सुझाव: कार्ड को समतल पकड़ें और अच्छी रोशनी रखें। छाया और चमक से बचें।',
        'পরামর্শ: কার্ড সমতলভাবে ধরুন, ভালো আলো রাখুন। ছায়া ও ঝলক এড়িয়ে চলুন।',
      );
  String get uploadBothHint => _p(
        'Upload both documents to continue.',
        'आगे बढ़ने के लिए दोनों दस्तावेज़ अपलोड करें।',
        'এগিয়ে যেতে দুটি নথিই আপলোড করুন।',
      );
  String get takePhoto => _p('Take Photo', 'फ़ोटो लें', 'ছবি তুলুন');
  String get choosePhotoSource =>
      _p('Choose photo source', 'फ़ोटो स्रोत चुनें', 'ছবির উৎস বেছে নিন');
  String get takeAPhoto => _p('Take a photo', 'फ़ोटो लें', 'ছবি তুলুন');
  String get chooseFromGallery =>
      _p('Choose from gallery', 'गैलरी से चुनें', 'গ্যালারি থেকে বেছে নিন');
  String get retake => _p('Retake', 'फिर से लें', 'আবার তুলুন');
  String get bothPhotosNeeded => _p(
        'Please take both document photos before continuing.',
        'आगे बढ़ने से पहले दोनों दस्तावेज़ों की फ़ोटो लें।',
        'এগিয়ে যাওয়ার আগে দুটি নথিরই ছবি তুলুন।',
      );

  // ── Details step ────────────────────────────────────────────────────────────
  String get whoIsThisFor =>
      _p('Who is this for?', 'यह किसके लिए है?', 'এটি কার জন্য?');
  String get selfServe => _p('Self-serve', 'स्वयं के लिए', 'নিজের জন্য');
  String get selfServeSub => _p('I am filling this for myself',
      'मैं यह अपने लिए भर रहा/रही हूँ', 'আমি নিজের জন্য পূরণ করছি');
  String get assisted =>
      _p('Assisted / Proxy', 'सहायता / किसी और के लिए', 'সহায়তা / অন্যের হয়ে');
  String get assistedSub => _p(
        'I am helping someone else (CSC, family)',
        'मैं किसी और की मदद कर रहा/रही हूँ (CSC, परिवार)',
        'আমি অন্য কাউকে সাহায্য করছি (CSC, পরিবার)',
      );
  String get whatHappened => _p('What happened?', 'क्या हुआ?', 'কী হয়েছিল?');
  String get whatHappenedSub => _p(
        'Select the symptom that best describes the problem.',
        'समस्या को सबसे सही बताने वाला विकल्प चुनें।',
        'সমস্যাটি সবচেয়ে ভালোভাবে বোঝায় এমন বিকল্প বেছে নিন।',
      );
  String get whereHappened =>
      _p('Where did it happen?', 'यह कहाँ हुआ?', 'এটি কোথায় হয়েছিল?');
  String get whereHappenedSub => _p(
        'Enter the name or ID of the Fair Price Shop (FPS).',
        'राशन की दुकान (FPS) का नाम या आईडी डालें।',
        'রেশন দোকানের (FPS) নাম বা আইডি লিখুন।',
      );
  String get locationHint => _p('e.g. Silchar FPS #4471',
      'जैसे Silchar FPS #4471', 'যেমন Silchar FPS #4471');
  String get analyse => _p('Analyse →', 'जाँचें →', 'বিশ্লেষণ →');
  String get selectToContinue => _p(
        'Please select what happened to continue.',
        'आगे बढ़ने के लिए चुनें कि क्या हुआ।',
        'এগিয়ে যেতে কী হয়েছিল তা বেছে নিন।',
      );
  String get back => _p('Back', 'पीछे', 'পিছনে');

  /// Localised label for a [Symptom].
  String symptomLabel(Symptom s) {
    switch (s) {
      case Symptom.turnedAwayAtFps:
        return _p('Turned away at shop', 'दुकान से लौटा दिया गया',
            'দোকান থেকে ফিরিয়ে দেওয়া হয়েছে');
      case Symptom.cardNotFound:
        return _p('Card not found at shop', 'दुकान पर कार्ड नहीं मिला',
            'দোকানে কার্ড পাওয়া যায়নি');
      case Symptom.biometricFailed:
        return _p('Biometric / fingerprint failed',
            'बायोमेट्रिक / फिंगरप्रिंट विफल', 'বায়োমেট্রিক / আঙুলের ছাপ ব্যর্থ');
      case Symptom.nameNotMatching:
        return _p('Name not matching', 'नाम मेल नहीं खा रहा', 'নাম মিলছে না');
      case Symptom.other:
        return _p('Other / not sure', 'अन्य / पता नहीं', 'অন্যান্য / নিশ্চিত নই');
    }
  }

  // ── Verify step ─────────────────────────────────────────────────────────────
  List<String> get verifyPhases => [
        _p('Reading your documents…', 'आपके दस्तावेज़ पढ़े जा रहे हैं…',
            'আপনার নথি পড়া হচ্ছে…'),
        _p('Comparing names across scripts…',
            'अलग-अलग लिपियों में नामों की तुलना…',
            'বিভিন্ন লিপিতে নাম মেলানো হচ্ছে…'),
        _p('Applying diagnosis rules…', 'निदान नियम लागू किए जा रहे हैं…',
            'নির্ণয়ের নিয়ম প্রয়োগ করা হচ্ছে…'),
        _p('Preparing your result…', 'आपका परिणाम तैयार किया जा रहा है…',
            'আপনার ফলাফল প্রস্তুত হচ্ছে…'),
      ];
  String get loadingBody => _p(
        'Using OCR and transliteration-aware matching to compare your Aadhaar and ration card records.',
        'आपके आधार और राशन कार्ड का मिलान OCR और लिप्यंतरण-आधारित तुलना से किया जा रहा है।',
        'OCR এবং প্রতিবর্ণীকরণ-সচেতন মিলকরণ ব্যবহার করে আপনার আধার ও রেশন কার্ডের তথ্য মেলানো হচ্ছে।',
      );
  String get securityNote => _p(
        'Your documents are processed securely and not stored.',
        'आपके दस्तावेज़ सुरक्षित रूप से संसाधित होते हैं और सहेजे नहीं जाते।',
        'আপনার নথি নিরাপদে প্রক্রিয়া করা হয় এবং সংরক্ষণ করা হয় না।',
      );
  String get docUnreadableTitle => _p('Document unreadable',
      'दस्तावेज़ पढ़ा नहीं जा सका', 'নথি পড়া যায়নি');
  String get docUnreadableMsg => _p(
        'The photo was too blurry. Please retake with better lighting.',
        'फ़ोटो बहुत धुंधली थी। बेहतर रोशनी में फिर से लें।',
        'ছবিটি খুব ঝাপসা ছিল। ভালো আলোয় আবার তুলুন।',
      );
  String get retakePhotos =>
      _p('← Retake Photos', '← फिर से फ़ोटो लें', '← আবার ছবি তুলুন');
  String get serverErrorTitle => _p('Could not reach server',
      'सर्वर से संपर्क नहीं हुआ', 'সার্ভারে পৌঁছানো যায়নি');
  String get networkError => _p('Network error.', 'नेटवर्क त्रुटि।', 'নেটওয়ার্ক ত্রুটি।');
  String get retry => _p('Retry', 'फिर कोशिश करें', 'আবার চেষ্টা করুন');
  String get verifyTitle => _p('Verify extracted details',
      'निकाली गई जानकारी जाँचें', 'উদ্ধার করা তথ্য যাচাই করুন');
  String get verifySubtitle => _p(
        'We read the text from your documents. Please check these match what is printed on your cards.',
        'हमने आपके दस्तावेज़ों से जानकारी पढ़ी है। कृपया जाँचें कि यह आपके कार्ड पर छपी जानकारी से मेल खाती है।',
        'আমরা আপনার নথি থেকে তথ্য পড়েছি। দয়া করে দেখে নিন এটি কার্ডে ছাপানো তথ্যের সঙ্গে মেলে কিনা।',
      );
  String get nameOnAadhaar =>
      _p('NAME ON AADHAAR', 'आधार पर नाम', 'আধারে নাম');
  String get nameOnRation => _p('NAME ON RATION CARD (Romanised)',
      'राशन कार्ड पर नाम (रोमन में)', 'রেশন কার্ডে নাম (রোমান হরফে)');
  String get notExtracted => _p('Not extracted', 'नहीं मिला', 'পাওয়া যায়নি');
  String get scriptLabel => _p('Script', 'मूल लिपि', 'মূল লিপি');
  String get mismatchBanner => _p(
        'Name mismatch detected between the two cards. This is a common cause of silent exclusion.',
        'दोनों कार्डों के नाम में अंतर पाया गया। यह चुपचाप बहिष्कार का एक आम कारण है।',
        'দুই কার্ডের নামে গরমিল পাওয়া গেছে। এটি নীরব বঞ্চনার একটি সাধারণ কারণ।',
      );
  String get dobLabel => _p('DATE OF BIRTH', 'जन्म तिथि', 'জন্ম তারিখ');
  String get aadhaarShort => _p('Aadhaar', 'आधार', 'আধার');
  String get rationShort => _p('Ration', 'राशन', 'রেশন');
  String get goBack => _p('Go Back', 'पीछे जाएँ', 'পিছনে যান');
  String get seeResults => _p('See Results', 'परिणाम देखें', 'ফলাফল দেখুন');

  /// Confidence label with a leading dot (verify badge).
  String confidenceBadge(Confidence c) {
    switch (c) {
      case Confidence.high:
        return _p('● High confidence', '● उच्च विश्वसनीयता', '● উচ্চ আস্থা');
      case Confidence.medium:
        return _p('● Medium confidence', '● मध्यम विश्वसनीयता', '● মাঝারি আস্থা');
      case Confidence.low:
        return _p('● Low confidence', '● कम विश्वसनीयता', '● কম আস্থা');
    }
  }

  // ── Results step ────────────────────────────────────────────────────────────
  String get likelyCause => _p('Likely cause', 'संभावित कारण', 'সম্ভাব্য কারণ');
  String get whatToDoNext => _p('What to do next', 'आगे क्या करें', 'এরপর কী করবেন');
  String get goTo => _p('Go to', 'यहाँ जाएँ', 'এখানে যান');
  String get askForForm => _p('Ask for form', 'यह फ़ॉर्म माँगें', 'এই ফর্ম চান');
  String get bringBoth => _p(
        'Bring both your Aadhaar card and ration card when you visit.',
        'जाते समय अपना आधार कार्ड और राशन कार्ड दोनों साथ ले जाएँ।',
        'যাওয়ার সময় আপনার আধার কার্ড ও রেশন কার্ড দুটোই সঙ্গে নিন।',
      );
  String get youAreNotAlone =>
      _p('You are not alone', 'आप अकेले नहीं हैं', 'আপনি একা নন');
  String get everyDiagnosis => _p(
        'Every diagnosis helps surface systemic defects that officials can act on.',
        'हर निदान उन व्यवस्थागत खामियों को सामने लाता है जिन पर अधिकारी कार्रवाई कर सकते हैं।',
        'প্রতিটি নির্ণয় এমন ব্যবস্থাগত ত্রুটি সামনে আনে যেগুলোর ওপর কর্মকর্তারা ব্যবস্থা নিতে পারেন।',
      );
  String get aiGenerated =>
      _p('AI-generated explanation', 'एआई-जनित व्याख्या', 'এআই-উৎপন্ন ব্যাখ্যা');
  String get offlineExplanation =>
      _p('Offline explanation', 'ऑफ़लाइन व्याख्या', 'অফলাইন ব্যাখ্যা');
  String get flagIncorrect => _p('Flag this diagnosis as incorrect',
      'इस निदान को ग़लत बताएँ', 'এই নির্ণয়কে ভুল হিসেবে চিহ্নিত করুন');
  String get feedbackThanks => _p(
        'Thank you — your feedback has been recorded for review.',
        'धन्यवाद — आपकी प्रतिक्रिया समीक्षा के लिए दर्ज कर ली गई है।',
        'ধন্যবাদ — আপনার মতামত পর্যালোচনার জন্য নথিভুক্ত করা হয়েছে।',
      );
  String get startNewDiagnosis => _p('Start a new diagnosis',
      'नया निदान शुरू करें', 'নতুন নির্ণয় শুরু করুন');
  String get weFoundIssue => _p('We found the likely issue',
      'हमें संभावित समस्या मिली', 'আমরা সম্ভাব্য সমস্যাটি খুঁজে পেয়েছি');
  String get flagAsIncorrect =>
      _p('Flag as incorrect', 'ग़लत बताएँ', 'ভুল হিসেবে চিহ্নিত করুন');
  String get feedbackPrompt => _p(
        'Tell us what you think the real issue is (optional):',
        'बताएँ कि आपके अनुसार असली समस्या क्या है (वैकल्पिक):',
        'আপনার মতে আসল সমস্যা কী তা জানান (ঐচ্ছিক):',
      );
  String get feedbackHint => _p(
        'e.g. "My card was found but they still refused"',
        'जैसे "मेरा कार्ड मिल गया फिर भी मना कर दिया"',
        'যেমন "আমার কার্ড পাওয়া গেছে তবু তারা মানা করেছে"',
      );
  String get cancel => _p('Cancel', 'रद्द करें', 'বাতিল');
  String get submit => _p('Submit', 'भेजें', 'জমা দিন');
  String get diagnosisFailed =>
      _p('Diagnosis failed', 'निदान विफल', 'নির্ণয় ব্যর্থ');
  String get startOver => _p('Start over', 'फिर से शुरू करें', 'আবার শুরু করুন');
  String get feedbackUnavailable => _p(
        'Feedback is unavailable — the diagnosis event was not recorded.',
        'प्रतिक्रिया उपलब्ध नहीं — निदान घटना दर्ज नहीं हुई थी।',
        'মতামত উপলব্ধ নয় — নির্ণয়ের ঘটনাটি নথিভুক্ত হয়নি।',
      );
  String get feedbackError => _p(
        'Could not send feedback right now. Please try again.',
        'अभी प्रतिक्रिया नहीं भेजी जा सकी। कृपया फिर कोशिश करें।',
        'এই মুহূর্তে মতামত পাঠানো যায়নি। আবার চেষ্টা করুন।',
      );

  /// Confidence label used on the results hero row (no leading dot).
  String confidenceRow(Confidence c) {
    switch (c) {
      case Confidence.high:
        return _p('High confidence', 'उच्च विश्वसनीयता', 'উচ্চ আস্থা');
      case Confidence.medium:
        return _p('Medium confidence', 'मध्यम विश्वसनीयता', 'মাঝারি আস্থা');
      case Confidence.low:
        return _p('Low confidence — verify carefully',
            'कम विश्वसनीयता — ध्यान से जाँचें', 'কম আস্থা — যত্নসহকারে যাচাই করুন');
    }
  }

  /// Localised label for a [RootCause].
  String rootCauseLabel(RootCause c) {
    switch (c) {
      case RootCause.nameMismatch:
        return _p('Name Mismatch', 'नाम में अंतर', 'নামে গরমিল');
      case RootCause.dobMismatch:
        return _p('Date of Birth Mismatch', 'जन्म तिथि में अंतर',
            'জন্ম তারিখে গরমিল');
      case RootCause.seedingGap:
        return _p('Aadhaar Seeding Gap', 'आधार सीडिंग में कमी',
            'আধার সিডিং ঘাটতি');
      case RootCause.ekycIncomplete:
        return _p('e-KYC Incomplete', 'ई-केवाईसी अधूरा', 'ই-কেওয়াইসি অসম্পূর্ণ');
      case RootCause.biometricFailure:
        return _p('Biometric Failure', 'बायोमेट्रिक विफलता', 'বায়োমেট্রিক ব্যর্থতা');
      case RootCause.unknown:
        return _p('Unknown Cause', 'अज्ञात कारण', 'অজানা কারণ');
    }
  }

  String clusterMatch(int count, String location, String cause) => _p(
        '$count people at $location are affected by the same $cause issue.',
        '$location पर $count लोग इसी $cause समस्या से प्रभावित हैं।',
        '$location-এ $count জন একই $cause সমস্যায় আক্রান্ত।',
      );
  String clusterGeneral(int total, int locations) => _p(
        '$total anonymised cases across $locations locations show similar exclusion patterns.',
        '$locations स्थानों पर $total गुमनाम मामले इसी तरह के बहिष्कार का पैटर्न दिखाते हैं।',
        '$locations টি স্থানে $total টি বেনামি ঘটনা একই ধরনের বঞ্চনার প্যাটার্ন দেখায়।',
      );
}

/// Publishes the active [AppStrings] to descendant widgets.
///
/// Wrap the app/wizard subtree in this and read it anywhere with
/// `AppText.of(context)`.  Changing [lang] notifies dependents so the whole
/// subtree re-renders in the new language.
class AppText extends InheritedWidget {
  final AppStrings strings;

  AppText({super.key, required String lang, required super.child})
      : strings = AppStrings(lang);

  static AppStrings of(BuildContext context) {
    final widget = context.dependOnInheritedWidgetOfExactType<AppText>();
    return widget?.strings ?? const AppStrings('en');
  }

  @override
  bool updateShouldNotify(AppText oldWidget) =>
      oldWidget.strings.lang != strings.lang;
}
