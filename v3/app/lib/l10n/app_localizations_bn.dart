// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bengali Bangla (`bn`).
class AppLocalizationsBn extends AppLocalizations {
  AppLocalizationsBn([String locale = 'bn']) : super(locale);

  @override
  String get appTitle => 'Firefox VPN';

  @override
  String get navOverview => 'সারসংক্ষেপ';

  @override
  String get navAccounts => 'অ্যাকাউন্ট';

  @override
  String get navSettings => 'সেটিংস';

  @override
  String get stateConnected => 'সংযুক্ত';

  @override
  String get stateConnecting => 'সংযোগ হচ্ছে…';

  @override
  String get stateWaiting => 'অপেক্ষা করছে';

  @override
  String get waitingForAccount =>
      'সংযোগ করতে অ্যাকাউন্ট পাতায় একটি Firefox Account যোগ করুন।';

  @override
  String get waitingForEnabledAccount =>
      'সব অ্যাকাউন্ট বন্ধ আছে। অ্যাকাউন্ট পাতা থেকে একটি চালু করুন।';

  @override
  String get stateError => 'ত্রুটি';

  @override
  String get stateUnknown => 'অজানা';

  @override
  String get restartProxy => 'প্রক্সি পুনরায় চালু করুন';

  @override
  String copied(String value) {
    return '$value কপি হয়েছে';
  }

  @override
  String get activeAccount => 'সক্রিয় অ্যাকাউন্ট';

  @override
  String get noActiveAccount => 'কোনো সক্রিয় অ্যাকাউন্ট নেই';

  @override
  String get quotaNotRead => 'ডেটার তথ্য এখনও আসেনি';

  @override
  String get unlimited => 'সীমাহীন';

  @override
  String usedOf(String used, String limit) {
    return '$limit-এর মধ্যে $used ব্যবহৃত';
  }

  @override
  String resets(String date) {
    return '$date তারিখে রিসেট হবে';
  }

  @override
  String switchAt(int percent) {
    return '$percent% হলে অ্যাকাউন্ট বদলাবে';
  }

  @override
  String get publicIp => 'পাবলিক IP';

  @override
  String get testConnection => 'সংযোগ পরীক্ষা করুন';

  @override
  String get testing => 'পরীক্ষা চলছে…';

  @override
  String get testFailed => 'ব্যর্থ';

  @override
  String milliseconds(int value) {
    return '$value ms';
  }

  @override
  String get justNow => 'এইমাত্র';

  @override
  String minutesAgo(int n) {
    return '$n মিনিট আগে';
  }

  @override
  String hoursAgo(int n) {
    return '$n ঘণ্টা আগে';
  }

  @override
  String daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count দিন আগে',
    );
    return '$_temp0';
  }

  @override
  String atTime(String time) {
    return '$time-এ';
  }

  @override
  String durationDays(int d, int h) {
    return '$d দিন $h ঘণ্টা';
  }

  @override
  String durationHours(int h, int m) {
    return '$h ঘ $m মি';
  }

  @override
  String durationMinutes(int m, int s) {
    return '$m মি $s সে';
  }

  @override
  String durationSeconds(int s) {
    return '$s সে';
  }

  @override
  String accountsGuide(String size) {
    return 'প্রতিটি Firefox Account-এ মাসে $size ডেটা থাকে। আপনি একাধিক অ্যাকাউন্ট যোগ করতে পারেন: একটির ডেটা শেষ হলে অ্যাপ নিজে থেকেই পরেরটিতে যায়।';
  }

  @override
  String accountsOrderNote(int percent) {
    return 'এই তালিকার ক্রমে: প্রতিটি অ্যাকাউন্ট $percent% পর্যন্ত, শেষটি ডেটা শেষ না হওয়া পর্যন্ত।';
  }

  @override
  String get addAccount => 'অ্যাকাউন্ট যোগ করুন';

  @override
  String lowQuotaNotice(String left, String size) {
    return 'বর্তমান অ্যাকাউন্টের ডেটা প্রায় শেষ ($left বাকি)। আরেকটি অ্যাকাউন্ট যোগ করলে আরও $size পাবেন।';
  }

  @override
  String get noAccounts => 'এখনও কোনো অ্যাকাউন্ট নেই';

  @override
  String get noAccountsHint => 'সংযোগ করতে একটি Firefox Account যোগ করুন।';

  @override
  String get createAccountTitle => 'Firefox Account নেই?';

  @override
  String get createAccountHint =>
      'accounts.firefox.com-এ বিনামূল্যে একটি তৈরি করুন, তারপর এখানে ফিরে “অ্যাকাউন্ট যোগ করুন” চাপুন।';

  @override
  String get moveUp => 'উপরে সরান';

  @override
  String get moveDown => 'নিচে সরান';

  @override
  String get statusActive => 'সক্রিয়';

  @override
  String get statusReady => 'প্রস্তুত';

  @override
  String get statusNeedsSignIn => 'সাইন-ইন দরকার';

  @override
  String get statusReserved => 'রিজার্ভ';

  @override
  String get statusUnavailable => 'উপলভ্য নয়';

  @override
  String statusUnavailableUntil(String date) {
    return '$date পর্যন্ত উপলভ্য নয়';
  }

  @override
  String get statusDisabled => 'বন্ধ';

  @override
  String get statusEnabled => 'চালু';

  @override
  String get useNow => 'এখন ব্যবহার করুন';

  @override
  String get signInAgain => 'আবার সাইন ইন করুন';

  @override
  String reasonQuotaThreshold(int percent) {
    return 'এই অ্যাকাউন্টের ডেটা $percent% ব্যবহৃত হয়েছে, তাই পরের অ্যাকাউন্টটি চালু হয়েছে।';
  }

  @override
  String get reasonQuotaExhausted =>
      'এই মাসের ডেটা শেষ; মাসিক রিসেটের পর আবার ব্যবহার হবে।';

  @override
  String get reasonSignInRequired =>
      'এই অ্যাকাউন্ট ব্যবহার করতে আবার সাইন ইন করুন।';

  @override
  String get reasonSignInConfirm =>
      'Mozilla সাইন-ইন নিশ্চিত করতে বলছে: «আবার সাইন ইন করুন» চাপুন (শুধু কোড লাগবে)।';

  @override
  String reasonSignInFailed(String detail) {
    return 'স্বয়ংক্রিয় সাইন-ইন ব্যর্থ হয়েছে ($detail)। আবার সাইন ইন করুন।';
  }

  @override
  String reasonSignInWait(String time) {
    return 'শেষ স্বয়ংক্রিয় সাইন-ইন কিছুক্ষণ পরেই কাজ করা বন্ধ করেছে; পরের চেষ্টা $time-এ।';
  }

  @override
  String reasonSignInRetry(String detail, String time) {
    return 'স্বয়ংক্রিয় সাইন-ইন শেষ হয়নি ($detail); $time-এ আবার চেষ্টা হবে।';
  }

  @override
  String get reasonNotEntitled =>
      'Mozilla এই অ্যাকাউন্টটি গ্রহণ করেনি; পরে আবার চেষ্টা হবে।';

  @override
  String get more => 'আরও';

  @override
  String get refreshQuota => 'ডেটার হিসাব রিফ্রেশ করুন';

  @override
  String get remove => 'সরান';

  @override
  String get removeTitle => 'অ্যাকাউন্ট সরাবেন?';

  @override
  String removeBody(String name) {
    return '$name এবং এর সেভ করা সাইন-ইন এই ডিভাইস থেকে মুছে যাবে। পরে আবার যোগ করতে পারবেন।';
  }

  @override
  String get unlimitedQuota => 'সীমাহীন ডেটা';

  @override
  String get signInTitle => 'সাইন ইন';

  @override
  String get signInIntro => 'একটি Firefox Account দিয়ে সাইন ইন করুন।';

  @override
  String get email => 'ইমেইল';

  @override
  String get emailInvalid => 'অ্যাকাউন্টের ইমেইল লিখুন';

  @override
  String get password => 'পাসওয়ার্ড';

  @override
  String get passwordEmpty => 'পাসওয়ার্ড লিখুন';

  @override
  String get show => 'দেখান';

  @override
  String get hide => 'লুকান';

  @override
  String get signIn => 'সাইন ইন';

  @override
  String get continueLabel => 'চালিয়ে যান';

  @override
  String get done => 'সম্পন্ন';

  @override
  String get close => 'বন্ধ';

  @override
  String get cancel => 'বাতিল';

  @override
  String get tryAgain => 'আবার চেষ্টা করুন';

  @override
  String get signingIn => 'সাইন ইন হচ্ছে…';

  @override
  String get accountReady => 'অ্যাকাউন্ট প্রস্তুত';

  @override
  String get accountReadyHint => 'এটি অ্যাকাউন্ট তালিকার শেষে যোগ হয়েছে।';

  @override
  String get captchaLabel => 'ছবির অক্ষরগুলো';

  @override
  String get codeLabel => 'কোড';

  @override
  String get captchaBroken => 'CAPTCHA ছবিটি দেখানো যায়নি।';

  @override
  String stepEmailCode(String email) {
    return 'Mozilla $email-এ একটি কোড ইমেইল করেছে। এখানে লিখুন।';
  }

  @override
  String get stepTotp => 'আপনার অথেনটিকেটর অ্যাপের কোডটি লিখুন।';

  @override
  String stepUnblockCode(String email) {
    return 'Mozilla এই সাইন-ইনটিকে অস্বাভাবিক মনে করছে এবং $email-এ একটি আনব্লক কোড ইমেইল করেছে। এখানে লিখুন।';
  }

  @override
  String get stepCaptcha => 'ছবির অক্ষরগুলো টাইপ করুন।';

  @override
  String stepEmailLink(String email) {
    return 'Mozilla $email-এ যে নিশ্চিতকরণ লিংক পাঠিয়েছে সেটি খুলুন। বাকিটা নিজে থেকেই হয়ে যাবে।';
  }

  @override
  String get signInFailed => 'অ্যাকাউন্ট যোগ হয়নি।';

  @override
  String get signInCancelled => 'সাইন ইন বাতিল হয়েছে।';

  @override
  String get signInNoAccount => 'এই ইমেইলে কোনো Firefox Account নেই।';

  @override
  String get signInNoAccountHint =>
      'ইমেইলটি দেখুন, অথবা এই ইমেইল দিয়ে Mozilla-র সাইটে একটি বিনামূল্যের Firefox Account তৈরি করুন, ইনবক্স থেকে নিশ্চিত করুন, তারপর এখানে যোগ করুন।';

  @override
  String get createAccountButton => 'Firefox Account তৈরি করুন';

  @override
  String get signInWrongPassword => 'পাসওয়ার্ড ভুল।';

  @override
  String get signInNoPassword =>
      'এই অ্যাকাউন্টের কোনো পাসওয়ার্ড নেই: এটি Google বা Apple দিয়ে সাইন ইন করে তৈরি। একটি পাসওয়ার্ড সেট করুন, তারপর সেটি দিয়ে এখানে সাইন ইন করুন।';

  @override
  String get setPasswordButton => 'পাসওয়ার্ড সেট করুন';

  @override
  String get signInTooManyAttempts =>
      'অনেকবার চেষ্টা হয়েছে। কিছুক্ষণ অপেক্ষা করে আবার চেষ্টা করুন।';

  @override
  String get signInUnblockRejected =>
      'আনব্লক কোড গৃহীত হয়নি। Mozilla-র সর্বশেষ ইমেইলের কোডটি ব্যবহার করুন।';

  @override
  String get signInWrongCode =>
      'কোড ভুল বা মেয়াদোত্তীর্ণ। Mozilla-র সর্বশেষ ইমেইলের কোডটি ব্যবহার করুন; নতুন কোড পাঠালে পুরোনোটি আর কাজ করে না।';

  @override
  String get signInWrongTotp =>
      'কোড ভুল। অথেনটিকেটর অ্যাপ এখন যে কোড দেখাচ্ছে সেটি লিখুন।';

  @override
  String get signInTooManyCodes =>
      'অনেকগুলো ভুল কোড। আবার শুরু থেকে সাইন ইন করুন।';

  @override
  String get signInTimedOut => 'সাইন ইনে অনেক সময় লেগেছে। আবার শুরু করুন।';

  @override
  String get signInNetwork =>
      'Mozilla-তে পৌঁছানো যায়নি। ইন্টারনেট দেখে আবার চেষ্টা করুন।';

  @override
  String get coreConnecting => 'কোরের সাথে সংযোগ হচ্ছে…';

  @override
  String get coreLost => 'কোরের সাথে সংযোগ বিচ্ছিন্ন। আবার চেষ্টা হচ্ছে…';

  @override
  String get cantReachCore => 'কোরে পৌঁছানো যাচ্ছে না';

  @override
  String get startingCore => 'কোর চালু হচ্ছে…';

  @override
  String get retry => 'আবার চেষ্টা';

  @override
  String errNoCore(String path) {
    return 'অ্যাপের পাশে কোর প্রোগ্রামটি পাওয়া যায়নি ($path)।';
  }

  @override
  String errCoreExited(String detail) {
    return 'কোর বন্ধ হয়ে গেছে: $detail';
  }

  @override
  String get errNotAnswering => 'কোর সাড়া দিচ্ছে না।';

  @override
  String get errRefused =>
      'কোর এই অ্যাপকে সংযোগ করতে দিচ্ছে না; সম্ভবত এটি অ্যাপের অন্য কোনো কপির কোর।';

  @override
  String get settingsTitle => 'সেটিংস';

  @override
  String get sectionGeneral => 'সাধারণ';

  @override
  String get language => 'ভাষা';

  @override
  String get languageSystem => 'সিস্টেম ডিফল্ট';

  @override
  String get theme => 'থিম';

  @override
  String get themeSystem => 'সিস্টেম';

  @override
  String get themeLight => 'লাইট';

  @override
  String get themeDark => 'ডার্ক';

  @override
  String get closeBehavior => 'উইন্ডো বন্ধ করার সময়';

  @override
  String get closeAsk => 'প্রতিবার জিজ্ঞেস করুন';

  @override
  String get closeTray => 'সিস্টেম ট্রে-তে লুকান';

  @override
  String get closeQuit => 'অ্যাপ বন্ধ করুন';

  @override
  String get sectionConnection => 'সংযোগ';

  @override
  String get localProxy => 'লোকাল প্রক্সি';

  @override
  String get systemProxy => 'সিস্টেম প্রক্সি';

  @override
  String get sectionRouting => 'রাউটিং';

  @override
  String get routingDirect => 'দেশি সাইটে সরাসরি সংযোগ';

  @override
  String get routingDirectHint =>
      'নির্বাচিত দেশের সাইট ও IP VPN ছাড়া সরাসরি খোলে, তাই দ্রুত লোড হয় এবং ডেটা বাঁচে।';

  @override
  String get region => 'দেশ';

  @override
  String get regionIr => 'ইরান';

  @override
  String get regionCn => 'চীন';

  @override
  String get regionRu => 'রাশিয়া';

  @override
  String get regionAf => 'আফগানিস্তান';

  @override
  String get regionTr => 'তুরস্ক';

  @override
  String get regionId => 'ইন্দোনেশিয়া';

  @override
  String get regionBr => 'ব্রাজিল';

  @override
  String get regionNone => 'কোনোটি নয়';

  @override
  String get saved => 'সেভ হয়েছে';

  @override
  String get dataFolder => 'ডেটা ফোল্ডার';

  @override
  String get openFolder => 'ফোল্ডার খুলুন';

  @override
  String get unofficialNote =>
      'এটি অফিসিয়াল ক্লায়েন্ট নয়। Mozilla-র সাথে এর কোনো সম্পর্ক নেই।';

  @override
  String get closeTitle => 'উইন্ডো বন্ধ করবেন?';

  @override
  String get closeBody =>
      'ট্রে-তে থাকলে VPN চালু থাকে। অ্যাপ বন্ধ করলে VPN-ও বন্ধ হয়ে যাবে।';

  @override
  String get rememberChoice => 'আমার পছন্দ মনে রাখুন';

  @override
  String get minimizeToTray => 'ট্রে-তে লুকান';

  @override
  String get quit => 'বেরিয়ে যান';

  @override
  String get trayOpen => 'খুলুন';

  @override
  String get trayQuit => 'বেরিয়ে যান';

  @override
  String get trayProxyOnly => 'শুধু প্রক্সি সার্ভিস';

  @override
  String get traySetSystemProxy => 'সিস্টেম প্রক্সি সেট করুন';

  @override
  String errPortInUse(String port) {
    return 'পোর্ট $port অন্য একটি প্রোগ্রাম ব্যবহার করছে, তাই অ্যাপটি তার কোরে পৌঁছাতে পারছে না।';
  }

  @override
  String proxyPortInUse(String port) {
    return 'পোর্ট $port অন্য একটি প্রোগ্রাম ব্যবহার করছে, তাই প্রক্সি চালু হতে পারছে না।';
  }

  @override
  String get changePort => 'পোর্ট বদলান';

  @override
  String get portDialogTitle => 'একটি পোর্ট বেছে নিন';

  @override
  String portDialogBody(String port) {
    return 'পোর্ট $port ব্যস্ত। নিচে একটি খালি পোর্ট দেওয়া হয়েছে; চাইলে অন্য একটি লিখতে পারেন।';
  }

  @override
  String get portChangeBody =>
      'অ্যাপগুলো এই পোর্টে সংযোগ করে। 1024 থেকে 65535-এর মধ্যে একটি বেছে নিন।';

  @override
  String get portLabel => 'পোর্ট';

  @override
  String get portInvalid => '1024 থেকে 65535-এর মধ্যে একটি পোর্ট লিখুন';

  @override
  String get portBusy => 'এই পোর্টটিও ব্যস্ত';

  @override
  String get portInUse => 'অন্য একটি প্রোগ্রাম এই পোর্ট ব্যবহার করছে';

  @override
  String get save => 'সংরক্ষণ';

  @override
  String get proxyPort => 'প্রক্সি পোর্ট';

  @override
  String get appPort => 'অ্যাপ পোর্ট';

  @override
  String get welcomeTitle => 'স্বাগতম';

  @override
  String get welcomeBody =>
      'আপনার ভাষা ও দেশ বেছে নিন। আপনার দেশের সাইটগুলো VPN ছাড়া সরাসরি খুলবে, তাই দ্রুত লোড হবে এবং ডেটা বাঁচবে।';

  @override
  String get start => 'শুরু';

  @override
  String routingSuggestTitle(String country) {
    return '$country-এর সাইট সরাসরি খুলবেন?';
  }

  @override
  String routingSuggestBody(String country) {
    return '$country-এর সাইট ও IP VPN ছাড়া সরাসরি খুলবে। পরে রাউটিং থেকে এটি বদলাতে পারবেন।';
  }

  @override
  String get yes => 'হ্যাঁ';

  @override
  String get notNow => 'এখন নয়';

  @override
  String get navServers => 'সার্ভার';

  @override
  String get navLogs => 'লগ';

  @override
  String get realDelay => 'আসল ডিলে';

  @override
  String noticePort(String port) {
    return 'Mozilla-র প্রক্সি পোর্ট $port-এ সংযোগ করে না। শুধু 80, 443, 8080 ও 8443 পোর্ট VPN দিয়ে যায়।';
  }

  @override
  String get noticeCommand =>
      'একটি অ্যাপ UDP ব্যবহার করতে চেয়েছে (গেম, ভয়েস ও ভিডিও কল)। Mozilla-র প্রক্সি শুধু TCP সমর্থন করে, তাই এই ট্রাফিক যেতে পারে না।';

  @override
  String noticeTimes(int count, String time) {
    return '$count বার, শেষবার $time';
  }

  @override
  String get dismiss => 'বাদ দিন';

  @override
  String get modeRecommended => 'প্রস্তাবিত';

  @override
  String get modeFastest => 'দ্রুততম';

  @override
  String get modeRecommendedHint => 'Mozilla আপনার জন্য লোকেশন বেছে নেয়।';

  @override
  String get modeFastestHint =>
      'প্রতিবার সংযোগের সময় সবচেয়ে কম ডিলের লোকেশন।';

  @override
  String get testDelay => 'আসল ডিলে পরীক্ষা করুন';

  @override
  String get testingDelay => 'পরীক্ষা চলছে… এতে এক মিনিট লাগতে পারে';

  @override
  String get search => 'খুঁজুন';

  @override
  String get noAnswer => 'সাড়া নেই';

  @override
  String testedAgo(String ago) {
    return '$ago পরীক্ষা করা হয়েছে';
  }

  @override
  String delaySummary(int answered, int total) {
    return '$totalটির মধ্যে $answeredটি সাড়া দিয়েছে';
  }

  @override
  String get noServers =>
      'এখনও কোনো সার্ভার নেই। কোর Mozilla-র সাথে সংযুক্ত হলে এখানে দেখা যাবে।';

  @override
  String get levelAll => 'সব';

  @override
  String get filter => 'ফিল্টার';

  @override
  String get follow => 'স্বয়ংক্রিয় স্ক্রল';

  @override
  String get clear => 'মুছুন';

  @override
  String get copyAll => 'কপি';

  @override
  String get logsCopied => 'লগ কপি হয়েছে';

  @override
  String get noLogs => 'এখনও কোনো লগ নেই।';

  @override
  String get sectionAccounts => 'স্বয়ংক্রিয় অ্যাকাউন্ট বদল';

  @override
  String get switchThreshold => 'অ্যাকাউন্ট বদলের সীমা';

  @override
  String get switchThresholdHint =>
      'ডেটার এই অংশ খরচ হলে পরের অ্যাকাউন্টে চলে যায়।';

  @override
  String get sectionDns => 'DNS';

  @override
  String get dnsPreset => 'DNS সার্ভার';

  @override
  String get dnsSystem => 'সিস্টেম';

  @override
  String get dnsAuto => 'স্বয়ংক্রিয় (Cloudflare, Google, Quad9)';

  @override
  String get dnsCustom => 'কাস্টম';

  @override
  String get dnsCustomHint =>
      'প্রতি লাইনে একটি: https://…/dns-query, tls://…, অথবা একটি IP ঠিকানা।';

  @override
  String get dnsFallback => 'প্রয়োজনে সিস্টেম DNS ব্যবহার করুন';

  @override
  String get testDns => 'DNS পরীক্ষা করুন';

  @override
  String get transport => 'প্রোটোকল';

  @override
  String get transportH3 => 'HTTP/3 (QUIC)';

  @override
  String get transportH2 => 'HTTP/2 (TCP)';

  @override
  String get directRules => 'সরাসরি';

  @override
  String get directRulesHint =>
      'এই তালিকার সাইট ও ঠিকানাগুলো VPN ছাড়া, সরাসরি আপনার নিজের ইন্টারনেটে খোলে। বেছে নেওয়া দেশের নিয়মগুলো আগে থেকেই এখানে আছে: লাইন যোগ, বদল বা মুছতে পারেন। অন্য দেশ বেছে নিলে সেগুলো সেই দেশের নিয়মে বদলে যায়।';

  @override
  String get restoreRegionRules => 'দেশের নিয়ম ফিরিয়ে আনুন';

  @override
  String get blockRules => 'ব্লক';

  @override
  String get blockRulesHint =>
      'এই তালিকার সাইট ও ঠিকানাগুলো একেবারেই খোলে না, সরাসরিও না, VPN দিয়েও না: বিজ্ঞাপন বা যেসব সাইট কখনো খুলতে চান না সেগুলোর জন্য।';

  @override
  String get rulesTitle => 'নিয়ম';

  @override
  String get ruleSyntaxTitle => 'নিয়ম কীভাবে লিখবেন';

  @override
  String get resolveDomains => 'ডোমেইনেও IP নিয়ম প্রয়োগ করুন';

  @override
  String get routingLists => 'Geo ফাইল';

  @override
  String get listSource => 'তালিকার উৎস';

  @override
  String get listSourceCustom => 'কাস্টম';

  @override
  String listsUpdatedAgo(String ago) {
    return 'আপডেট হয়েছে $ago';
  }

  @override
  String get updateLists => 'Geo ফাইল আপডেট করুন';

  @override
  String get listsUpdated => 'Geo ফাইলগুলো আপডেট হয়েছে।';

  @override
  String get testDestination => 'সাইটের রুট যাচাই';

  @override
  String get destinationHint => 'সাইটের নাম, ঠিকানা বা URL';

  @override
  String get check => 'যাচাই';

  @override
  String get routeDirect => 'সরাসরি যায়';

  @override
  String get routeProxy => 'VPN দিয়ে যায়';

  @override
  String get routeBlock => 'ব্লক করা';

  @override
  String ruleMatched(String rule) {
    return 'নিয়ম: $rule';
  }

  @override
  String get portRefusedNote => 'Mozilla-র প্রক্সি এই পোর্টে সংযোগ করে না।';

  @override
  String get sectionAdvanced => 'উন্নত';

  @override
  String get listenAddress => 'প্রক্সি অ্যাক্সেস';

  @override
  String get listenLocal => '127.0.0.1 · শুধু এই ডিভাইস';

  @override
  String get listenAll => '0.0.0.0 · সব নেটওয়ার্ক (LAN)';

  @override
  String get proxyUsername => 'প্রক্সি ইউজারনেম';

  @override
  String get proxyPassword => 'প্রক্সি পাসওয়ার্ড';

  @override
  String get proxyLoginHint =>
      'প্রক্সি ব্যবহার করতে অ্যাপগুলোকে এই ইউজারনেম ও পাসওয়ার্ড দিতে হবে। পাসওয়ার্ড ছাড়া চালাতে দুটোই খালি রাখুন।';

  @override
  String get loginBothOrNone => 'দুটোই পূরণ করুন, অথবা দুটোই খালি রাখুন।';

  @override
  String get proxyLogin => 'প্রক্সি ইউজারনেম ও পাসওয়ার্ড';

  @override
  String get idleSleep => 'কতক্ষণ নিষ্ক্রিয় থাকলে স্লিপ';

  @override
  String get sleepNever => 'কখনো না';

  @override
  String sleepMinutes(int count) {
    return '$count মিনিট';
  }

  @override
  String get sleepHour => '1 ঘণ্টা';

  @override
  String get showPublicIp => 'পাবলিক IP দেখান';

  @override
  String get speedInNotification => 'বিজ্ঞপ্তিতে গতি দেখান';

  @override
  String get liveTraffic => 'লাইভ ট্রাফিক';

  @override
  String get totalTraffic => 'মোট ট্রাফিক';

  @override
  String get verboseLogs => 'বিস্তারিত লগ';

  @override
  String get webDashboard => 'ওয়েব ড্যাশবোর্ড';

  @override
  String get webDashboardOpen => 'খুলুন';

  @override
  String get webDashboardHint => 'উন্নত সেটিংস ও আরও টুল';

  @override
  String numberInvalid(int min, int max) {
    return '$min থেকে $max-এর মধ্যে একটি সংখ্যা লিখুন';
  }

  @override
  String get notifySwitchedTitle => 'অ্যাকাউন্ট বদলানো হয়েছে';

  @override
  String notifySwitchedBody(String name) {
    return 'এখন $name ব্যবহার হচ্ছে।';
  }

  @override
  String get notifySignInTitle => 'সাইন-ইন দরকার';

  @override
  String get notifySignInBody =>
      'একটি অ্যাকাউন্টে আবার সাইন ইন করা দরকার। অ্যাকাউন্ট পাতায় যান।';

  @override
  String get navAbout => 'সম্পর্কে';

  @override
  String get appVersionLabel => 'অ্যাপ সংস্করণ';

  @override
  String get coreVersionLabel => 'কোর সংস্করণ';

  @override
  String get checkUpdates => 'আপডেট আছে কিনা দেখুন';

  @override
  String get checkingUpdates => 'যাচাই হচ্ছে…';

  @override
  String get upToDate => 'আপনার কাছে সর্বশেষ সংস্করণ আছে।';

  @override
  String updateAvailable(String version) {
    return 'সংস্করণ $version পাওয়া যাচ্ছে।';
  }

  @override
  String get download => 'ডাউনলোড';

  @override
  String updateCheckFailed(String error) {
    return 'আপডেট যাচাই করা যায়নি: $error';
  }

  @override
  String get repoNotSet => 'GitHub রিপোজিটরি এখনও সেট করা হয়নি।';

  @override
  String get sourceCode => 'সোর্স কোড';

  @override
  String get tapToConnect => 'সংযোগ করতে ক্লিক করুন';

  @override
  String get tapToDisconnect => 'সংযোগ বিচ্ছিন্ন করতে ক্লিক করুন';

  @override
  String get startOnBoot => 'সিস্টেম চালু হলে শুরু করুন';

  @override
  String get connectOnStartup => 'চালু হলে স্বয়ংক্রিয়ভাবে সংযোগ করুন';

  @override
  String get proxyServiceActive => 'প্রক্সি সার্ভিস চালু আছে';

  @override
  String get navHome => 'হোম';

  @override
  String get groupApp => 'অ্যাপ';

  @override
  String get stateOff => 'সংযোগ বিচ্ছিন্ন';

  @override
  String get tapToConnectPhone => 'সংযোগ করতে ট্যাপ করুন';

  @override
  String get tapToDisconnectPhone => 'সংযোগ বিচ্ছিন্ন করতে ট্যাপ করুন';

  @override
  String lanAddress(String address) {
    return 'LAN $address';
  }

  @override
  String get recommendedLocation => 'প্রস্তাবিত লোকেশন';

  @override
  String dataLeftOf(String limit) {
    return '$limit-এর মধ্যে';
  }

  @override
  String get homeLocation => 'লোকেশন';

  @override
  String get connectedTo => 'সংযুক্ত:';

  @override
  String get vpnNotAllowed =>
      'VPN-এর জন্য আপনার অনুমতি দরকার। বোতামটি আবার ট্যাপ করে অনুমতি দিন।';

  @override
  String get dataUsedTitle => 'ব্যবহৃত ডেটা';

  @override
  String get bypassApps => 'অ্যাপভিত্তিক প্রক্সি';

  @override
  String get connectRetrying => 'সংযোগ করা যায়নি। ইন্টারনেট পরীক্ষা করুন।';

  @override
  String get failUnreachable =>
      'এই ইন্টারনেটে Mozilla-র সার্ভার ব্লক করা আছে। অন্য ইন্টারনেট সংযোগ চেষ্টা করুন।';

  @override
  String get failRefused =>
      'Mozilla-র সার্ভার সংযোগ প্রত্যাখ্যান করেছে। কয়েক মিনিট পরে আবার চেষ্টা করুন।';

  @override
  String get failLocationRefused =>
      'এই দেশটি আপনার অ্যাকাউন্টের জন্য খোলা নয়। অন্য দেশ বেছে নিন।';

  @override
  String get useRecommendedLocation => 'প্রস্তাবিত লোকেশন ব্যবহার করুন';

  @override
  String exitMismatch(String exit, String chosen) {
    return 'আপনি $chosen বেছে নিয়েছেন, কিন্তু আপনার IP-র দেশ: $exit।';
  }

  @override
  String get failSignIn =>
      'এই অ্যাকাউন্টের সাইন-ইনের মেয়াদ শেষ। অ্যাকাউন্ট পাতা থেকে আবার সাইন ইন করুন।';

  @override
  String get failQuota => 'এই মাসের ডেটা শেষ। আরেকটি অ্যাকাউন্ট যোগ করুন।';

  @override
  String get failNotEntitled =>
      'Mozilla এই অ্যাকাউন্টকে VPN ব্যবহার করতে দেয় না। আরেকটি অ্যাকাউন্ট যোগ করুন।';

  @override
  String get failRegion => 'আপনার দেশে Mozilla তার পরিষেবা দেয় না।';

  @override
  String get failServer =>
      'Mozilla-র পরিষেবায় সাময়িক সমস্যা হয়েছে। অ্যাপ নিজেই আবার চেষ্টা করবে।';

  @override
  String get failNoAccount =>
      'কোনো অ্যাকাউন্ট প্রস্তুত নেই। অ্যাকাউন্ট পাতা খুলুন।';

  @override
  String get failTestSite =>
      'সার্ভারে সংযুক্ত হয়েছে, কিন্তু সাইট খুলছে না। অন্য দেশ চেষ্টা করুন।';

  @override
  String get failOther => 'সংযোগ করা যায়নি। আবার চেষ্টা করুন।';

  @override
  String get failNoInternet =>
      'ইন্টারনেট নেই। Wi-Fi বা মোবাইল ডেটা পরীক্ষা করুন।';

  @override
  String get waitingForNetwork => 'ইন্টারনেট সংযোগের অপেক্ষায়…';

  @override
  String proxyStartFailed(String port) {
    return 'পোর্ট $port-এ প্রক্সি চালু হয়নি। অন্য একটি পোর্ট বেছে নিন।';
  }

  @override
  String get connectionSettings => 'সংযোগ সেটিংস';

  @override
  String get appModeExclude => 'নির্বাচিত অ্যাপ VPN ছাড়া';

  @override
  String get appModeInclude => 'শুধু নির্বাচিত অ্যাপ VPN-এ';

  @override
  String get appModeExcludeHint =>
      'নির্বাচিত অ্যাপগুলো VPN ছাড়া সরাসরি সংযোগ করে: যেমন বিদেশি ঠিকানা প্রত্যাখ্যান করে এমন ব্যাংকিং অ্যাপ।';

  @override
  String get appModeIncludeHint =>
      'শুধু নির্বাচিত অ্যাপগুলো VPN দিয়ে যায়; বাকিগুলো সরাসরি সংযোগ করে।';

  @override
  String fromRegionList(String region) {
    return 'প্রস্তাবিত: $region-এর তালিকায় আছে';
  }

  @override
  String get modeProxy => 'প্রক্সি';

  @override
  String get connectionMode => 'সংযোগ মোড';

  @override
  String get modeProxyHint =>
      'শুধু যেসব অ্যাপে প্রক্সি সেট করা আছে সেগুলোই এর মধ্য দিয়ে যায়; Windows-এর সেটিংস বদলায় না।';

  @override
  String get modeSystemProxyHint =>
      'Windows ও বেশিরভাগ অ্যাপ প্রক্সি দিয়ে যায়।';

  @override
  String get modeProxyHintOther =>
      'শুধু যেসব অ্যাপে প্রক্সি সেট করা আছে সেগুলোই এর মধ্য দিয়ে যায়; সিস্টেমের সেটিংস বদলায় না।';

  @override
  String get modeSystemProxyHintOther =>
      'ব্রাউজার ও বেশিরভাগ অ্যাপ প্রক্সি দিয়ে যায়।';

  @override
  String get suggestedApps => 'প্রস্তাবিত অ্যাপ';

  @override
  String suggestedAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countটি প্রস্তাবিত অ্যাপ নির্বাচিত',
      one: '1টি প্রস্তাবিত অ্যাপ নির্বাচিত',
      zero: 'প্রস্তাবিত অ্যাপগুলো আগেই নির্বাচিত',
    );
    return '$_temp0';
  }

  @override
  String get autoSection => 'স্বয়ংক্রিয়';

  @override
  String get locationsSection => 'লোকেশন';

  @override
  String get dnsSummaryOk => 'এনক্রিপ্টেড DNS কাজ করছে';

  @override
  String dnsSummaryFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countটি নাম রিজলভ হয়নি',
      one: '1টি নাম রিজলভ হয়নি',
    );
    return '$_temp0';
  }

  @override
  String dnsVia(String server) {
    return '$server দিয়ে';
  }

  @override
  String dnsSummaryDiffers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'আপনার নেটওয়ার্কের DNS $countটি নামের জন্য একটি ফিল্টারিং ঠিকানা দিয়েছে। এই অ্যাপ সেই উত্তরগুলো ব্যবহার করে না।',
      one: 'আপনার নেটওয়ার্কের DNS 1টি নামের জন্য একটি ফিল্টারিং ঠিকানা দিয়েছে। এই অ্যাপ সেই উত্তর ব্যবহার করে না।',
    );
    return '$_temp0';
  }

  @override
  String get dnsAnswer => 'উত্তর:';

  @override
  String get dnsNetworkAnswer => 'নেটওয়ার্ক DNS:';

  @override
  String get dnsFiltered => 'ফিল্টার করা';

  @override
  String get rulesSyntaxTitle => 'প্রতি লাইনে একটি নিয়ম';

  @override
  String get ruleDomain => 'সাইট ও এর সাবডোমেইন';

  @override
  String get ruleFull => 'ঠিক এই নামটি';

  @override
  String get ruleKeyword => 'যেসব নামে শব্দটি আছে';

  @override
  String get ruleGeosite => 'Geo ফাইলের একটি ট্যাগের সাইট';

  @override
  String get ruleGeoip => 'Geo ফাইলে থাকা একটি দেশের ঠিকানা';

  @override
  String get ruleIp => 'একটি ঠিকানা বা নেটওয়ার্ক';

  @override
  String get modeVpn => 'VPN';

  @override
  String get modeProxyOnly => 'শুধু প্রক্সি';

  @override
  String get noNetwork =>
      'ইন্টারনেট সংযোগ নেই। Wi-Fi বা মোবাইল ডেটা চালু করুন।';

  @override
  String get blockAds => 'বিজ্ঞাপন ব্লক করুন';

  @override
  String systemProxyTakenBy(String address) {
    return 'অন্য একটি প্রোগ্রাম সিস্টেম প্রক্সি $address-এ বদলে দিয়েছে, তাই ট্রাফিক VPN দিয়ে যাচ্ছে না।';
  }

  @override
  String get systemProxyTakenOff =>
      'অন্য একটি প্রোগ্রাম সিস্টেম প্রক্সি বন্ধ করে দিয়েছে, তাই ট্রাফিক VPN দিয়ে যাচ্ছে না।';

  @override
  String get setSystemProxyAgain => 'আবার সেট করুন';
}
