import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_az.dart';
import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fa.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_hu.dart';
import 'app_localizations_id.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_tr.dart';
import 'app_localizations_vi.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ar'),
    Locale('az'),
    Locale('bn'),
    Locale('es'),
    Locale('fa'),
    Locale('fr'),
    Locale('hu'),
    Locale('id'),
    Locale('pt'),
    Locale('ru'),
    Locale('tr'),
    Locale('vi'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Firefox VPN'**
  String get appTitle;

  /// No description provided for @navOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get navOverview;

  /// No description provided for @navAccounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get navAccounts;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @stateConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get stateConnected;

  /// No description provided for @stateConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get stateConnecting;

  /// No description provided for @stateWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get stateWaiting;

  /// No description provided for @waitingForAccount.
  ///
  /// In en, this message translates to:
  /// **'Add a Firefox Account on the Accounts page to connect.'**
  String get waitingForAccount;

  /// Home hint while the proxy waits: accounts exist, but every one is turned off.
  ///
  /// In en, this message translates to:
  /// **'All accounts are turned off. Turn one on in Accounts.'**
  String get waitingForEnabledAccount;

  /// No description provided for @stateError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get stateError;

  /// No description provided for @stateUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get stateUnknown;

  /// No description provided for @restartProxy.
  ///
  /// In en, this message translates to:
  /// **'Restart the proxy'**
  String get restartProxy;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied {value}'**
  String copied(String value);

  /// No description provided for @activeAccount.
  ///
  /// In en, this message translates to:
  /// **'Active account'**
  String get activeAccount;

  /// No description provided for @noActiveAccount.
  ///
  /// In en, this message translates to:
  /// **'No active account'**
  String get noActiveAccount;

  /// No description provided for @quotaNotRead.
  ///
  /// In en, this message translates to:
  /// **'Quota not read yet'**
  String get quotaNotRead;

  /// No description provided for @unlimited.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get unlimited;

  /// No description provided for @usedOf.
  ///
  /// In en, this message translates to:
  /// **'{used} of {limit} used'**
  String usedOf(String used, String limit);

  /// No description provided for @resets.
  ///
  /// In en, this message translates to:
  /// **'resets {date}'**
  String resets(String date);

  /// No description provided for @switchAt.
  ///
  /// In en, this message translates to:
  /// **'Switches account at {percent}%'**
  String switchAt(int percent);

  /// No description provided for @publicIp.
  ///
  /// In en, this message translates to:
  /// **'Public IP'**
  String get publicIp;

  /// No description provided for @testConnection.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get testConnection;

  /// No description provided for @testing.
  ///
  /// In en, this message translates to:
  /// **'Testing…'**
  String get testing;

  /// No description provided for @testFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get testFailed;

  /// No description provided for @milliseconds.
  ///
  /// In en, this message translates to:
  /// **'{value} ms'**
  String milliseconds(int value);

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} min ago'**
  String minutesAgo(int n);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} h ago'**
  String hoursAgo(int n);

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day ago} other{{count} days ago}}'**
  String daysAgo(int count);

  /// No description provided for @atTime.
  ///
  /// In en, this message translates to:
  /// **'at {time}'**
  String atTime(String time);

  /// No description provided for @durationDays.
  ///
  /// In en, this message translates to:
  /// **'{d}d {h}h'**
  String durationDays(int d, int h);

  /// No description provided for @durationHours.
  ///
  /// In en, this message translates to:
  /// **'{h}h {m}m'**
  String durationHours(int h, int m);

  /// No description provided for @durationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{m}m {s}s'**
  String durationMinutes(int m, int s);

  /// No description provided for @durationSeconds.
  ///
  /// In en, this message translates to:
  /// **'{s}s'**
  String durationSeconds(int s);

  /// No description provided for @accountsGuide.
  ///
  /// In en, this message translates to:
  /// **'Each Firefox Account has {size} of data a month. You can add several: when one runs out, the app moves to the next one by itself.'**
  String accountsGuide(String size);

  /// No description provided for @accountsOrderNote.
  ///
  /// In en, this message translates to:
  /// **'In the order of this list: each up to {percent}%, the last one until its data runs out.'**
  String accountsOrderNote(int percent);

  /// No description provided for @addAccount.
  ///
  /// In en, this message translates to:
  /// **'Add account'**
  String get addAccount;

  /// No description provided for @lowQuotaNotice.
  ///
  /// In en, this message translates to:
  /// **'The current account is running out of data ({left} left). Add another account to get {size} more.'**
  String lowQuotaNotice(String left, String size);

  /// No description provided for @noAccounts.
  ///
  /// In en, this message translates to:
  /// **'No accounts yet'**
  String get noAccounts;

  /// No description provided for @noAccountsHint.
  ///
  /// In en, this message translates to:
  /// **'Add a Firefox Account to connect.'**
  String get noAccountsHint;

  /// No description provided for @createAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have a Firefox Account?'**
  String get createAccountTitle;

  /// No description provided for @createAccountHint.
  ///
  /// In en, this message translates to:
  /// **'Create one for free at accounts.firefox.com, then come back and press Add account.'**
  String get createAccountHint;

  /// No description provided for @moveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get moveUp;

  /// No description provided for @moveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get moveDown;

  /// No description provided for @statusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get statusActive;

  /// No description provided for @statusReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get statusReady;

  /// No description provided for @statusNeedsSignIn.
  ///
  /// In en, this message translates to:
  /// **'Needs sign-in'**
  String get statusNeedsSignIn;

  /// No description provided for @statusReserved.
  ///
  /// In en, this message translates to:
  /// **'Reserved'**
  String get statusReserved;

  /// No description provided for @statusUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get statusUnavailable;

  /// No description provided for @statusUnavailableUntil.
  ///
  /// In en, this message translates to:
  /// **'Unavailable until {date}'**
  String statusUnavailableUntil(String date);

  /// No description provided for @statusDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get statusDisabled;

  /// No description provided for @statusEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get statusEnabled;

  /// No description provided for @useNow.
  ///
  /// In en, this message translates to:
  /// **'Use now'**
  String get useNow;

  /// No description provided for @signInAgain.
  ///
  /// In en, this message translates to:
  /// **'Sign in again'**
  String get signInAgain;

  /// An account set aside at the switch threshold (percent, the setting) while the next account is used.
  ///
  /// In en, this message translates to:
  /// **'Used {percent}% of its data, so the next account took over.'**
  String reasonQuotaThreshold(int percent);

  /// No description provided for @reasonQuotaExhausted.
  ///
  /// In en, this message translates to:
  /// **'This month\'s data is used up; it is used again after the monthly reset.'**
  String get reasonQuotaExhausted;

  /// No description provided for @reasonSignInRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in again to use this account.'**
  String get reasonSignInRequired;

  /// No description provided for @reasonSignInConfirm.
  ///
  /// In en, this message translates to:
  /// **'Mozilla asks to confirm the sign-in: press Sign in again (only the code is needed).'**
  String get reasonSignInConfirm;

  /// No description provided for @reasonSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Automatic sign-in failed ({detail}). Sign in again.'**
  String reasonSignInFailed(String detail);

  /// No description provided for @reasonSignInWait.
  ///
  /// In en, this message translates to:
  /// **'The last automatic sign-in stopped working soon after; the next try is at {time}.'**
  String reasonSignInWait(String time);

  /// No description provided for @reasonSignInRetry.
  ///
  /// In en, this message translates to:
  /// **'Automatic sign-in could not finish ({detail}); trying again at {time}.'**
  String reasonSignInRetry(String detail, String time);

  /// No description provided for @reasonNotEntitled.
  ///
  /// In en, this message translates to:
  /// **'Mozilla refused this account; trying again later.'**
  String get reasonNotEntitled;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @refreshQuota.
  ///
  /// In en, this message translates to:
  /// **'Refresh quota'**
  String get refreshQuota;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @removeTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove account?'**
  String get removeTitle;

  /// No description provided for @removeBody.
  ///
  /// In en, this message translates to:
  /// **'{name} and its saved sign-in will be removed from this computer. You can add it again later.'**
  String removeBody(String name);

  /// No description provided for @unlimitedQuota.
  ///
  /// In en, this message translates to:
  /// **'Unlimited quota'**
  String get unlimitedQuota;

  /// No description provided for @signInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInTitle;

  /// No description provided for @signInIntro.
  ///
  /// In en, this message translates to:
  /// **'Sign in with a Firefox Account.'**
  String get signInIntro;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @emailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter the account email'**
  String get emailInvalid;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @passwordEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter the password'**
  String get passwordEmpty;

  /// No description provided for @show.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get show;

  /// No description provided for @hide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get hide;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @signingIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in…'**
  String get signingIn;

  /// No description provided for @accountReady.
  ///
  /// In en, this message translates to:
  /// **'Account ready'**
  String get accountReady;

  /// No description provided for @accountReadyHint.
  ///
  /// In en, this message translates to:
  /// **'It joined the end of the account order.'**
  String get accountReadyHint;

  /// No description provided for @captchaLabel.
  ///
  /// In en, this message translates to:
  /// **'Characters in the image'**
  String get captchaLabel;

  /// No description provided for @codeLabel.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get codeLabel;

  /// No description provided for @captchaBroken.
  ///
  /// In en, this message translates to:
  /// **'The CAPTCHA image could not be shown.'**
  String get captchaBroken;

  /// No description provided for @stepEmailCode.
  ///
  /// In en, this message translates to:
  /// **'Mozilla emailed a code to {email}. Enter it here.'**
  String stepEmailCode(String email);

  /// No description provided for @stepTotp.
  ///
  /// In en, this message translates to:
  /// **'Enter the code from your authenticator app.'**
  String get stepTotp;

  /// No description provided for @stepUnblockCode.
  ///
  /// In en, this message translates to:
  /// **'Mozilla finds this sign-in unusual and emailed an unblock code to {email}. Enter it here.'**
  String stepUnblockCode(String email);

  /// No description provided for @stepCaptcha.
  ///
  /// In en, this message translates to:
  /// **'Type the characters in the image.'**
  String get stepCaptcha;

  /// No description provided for @stepEmailLink.
  ///
  /// In en, this message translates to:
  /// **'Open the confirmation link Mozilla emailed to {email}. This continues by itself.'**
  String stepEmailLink(String email);

  /// No description provided for @signInFailed.
  ///
  /// In en, this message translates to:
  /// **'The account was not added.'**
  String get signInFailed;

  /// No description provided for @signInCancelled.
  ///
  /// In en, this message translates to:
  /// **'Sign-in cancelled.'**
  String get signInCancelled;

  /// No description provided for @signInNoAccount.
  ///
  /// In en, this message translates to:
  /// **'No Firefox Account exists for this email.'**
  String get signInNoAccount;

  /// No description provided for @signInNoAccountHint.
  ///
  /// In en, this message translates to:
  /// **'Check the email, or create a free Firefox Account with it on Mozilla\'s site, confirm it from your inbox, then add it here.'**
  String get signInNoAccountHint;

  /// No description provided for @createAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Create a Firefox Account'**
  String get createAccountButton;

  /// No description provided for @signInWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password.'**
  String get signInWrongPassword;

  /// Sign-in failed: the Firefox Account was made with Google or Apple sign-in and has no password (FxA errno 210).
  ///
  /// In en, this message translates to:
  /// **'This account has no password: it was made with Google or Apple sign-in. Set a password, then sign in here with it.'**
  String get signInNoPassword;

  /// Button in place of Try again after signInNoPassword; opens Mozilla's page to set a password.
  ///
  /// In en, this message translates to:
  /// **'Set a password'**
  String get setPasswordButton;

  /// No description provided for @signInTooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a while and try again.'**
  String get signInTooManyAttempts;

  /// No description provided for @signInUnblockRejected.
  ///
  /// In en, this message translates to:
  /// **'The unblock code was not accepted. Use the code from the latest email from Mozilla.'**
  String get signInUnblockRejected;

  /// No description provided for @signInWrongCode.
  ///
  /// In en, this message translates to:
  /// **'Wrong or expired code. Use the code from the latest email from Mozilla; an older code stops working when a new one is sent.'**
  String get signInWrongCode;

  /// No description provided for @signInWrongTotp.
  ///
  /// In en, this message translates to:
  /// **'Wrong code. Enter the code the authenticator app shows now.'**
  String get signInWrongTotp;

  /// No description provided for @signInTooManyCodes.
  ///
  /// In en, this message translates to:
  /// **'Too many wrong codes. Start the sign-in again.'**
  String get signInTooManyCodes;

  /// No description provided for @signInTimedOut.
  ///
  /// In en, this message translates to:
  /// **'The sign-in took too long. Start it again.'**
  String get signInTimedOut;

  /// No description provided for @signInNetwork.
  ///
  /// In en, this message translates to:
  /// **'Mozilla could not be reached. Check your internet and try again.'**
  String get signInNetwork;

  /// No description provided for @coreConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting to the core…'**
  String get coreConnecting;

  /// No description provided for @coreLost.
  ///
  /// In en, this message translates to:
  /// **'Lost the connection to the core. Retrying…'**
  String get coreLost;

  /// No description provided for @cantReachCore.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the core'**
  String get cantReachCore;

  /// No description provided for @startingCore.
  ///
  /// In en, this message translates to:
  /// **'Starting the core…'**
  String get startingCore;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @errNoCore.
  ///
  /// In en, this message translates to:
  /// **'The core program was not found next to the app ({path}).'**
  String errNoCore(String path);

  /// No description provided for @errCoreExited.
  ///
  /// In en, this message translates to:
  /// **'The core stopped: {detail}'**
  String errCoreExited(String detail);

  /// No description provided for @errNotAnswering.
  ///
  /// In en, this message translates to:
  /// **'The core is not answering.'**
  String get errNotAnswering;

  /// No description provided for @errRefused.
  ///
  /// In en, this message translates to:
  /// **'The core refused the app; it may belong to another copy.'**
  String get errRefused;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @sectionGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get sectionGeneral;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @closeBehavior.
  ///
  /// In en, this message translates to:
  /// **'When closing the window'**
  String get closeBehavior;

  /// No description provided for @closeAsk.
  ///
  /// In en, this message translates to:
  /// **'Ask every time'**
  String get closeAsk;

  /// No description provided for @closeTray.
  ///
  /// In en, this message translates to:
  /// **'Minimize to the tray'**
  String get closeTray;

  /// No description provided for @closeQuit.
  ///
  /// In en, this message translates to:
  /// **'Quit the app'**
  String get closeQuit;

  /// No description provided for @sectionConnection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get sectionConnection;

  /// No description provided for @localProxy.
  ///
  /// In en, this message translates to:
  /// **'Local proxy'**
  String get localProxy;

  /// No description provided for @systemProxy.
  ///
  /// In en, this message translates to:
  /// **'System proxy'**
  String get systemProxy;

  /// No description provided for @sectionRouting.
  ///
  /// In en, this message translates to:
  /// **'Routing'**
  String get sectionRouting;

  /// No description provided for @routingDirect.
  ///
  /// In en, this message translates to:
  /// **'Direct connection for local sites'**
  String get routingDirect;

  /// No description provided for @routingDirectHint.
  ///
  /// In en, this message translates to:
  /// **'Sites and IPs of the chosen country skip the VPN: they open faster and save quota.'**
  String get routingDirectHint;

  /// No description provided for @region.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get region;

  /// No description provided for @regionIr.
  ///
  /// In en, this message translates to:
  /// **'Iran'**
  String get regionIr;

  /// No description provided for @regionCn.
  ///
  /// In en, this message translates to:
  /// **'China'**
  String get regionCn;

  /// No description provided for @regionRu.
  ///
  /// In en, this message translates to:
  /// **'Russia'**
  String get regionRu;

  /// No description provided for @regionAf.
  ///
  /// In en, this message translates to:
  /// **'Afghanistan'**
  String get regionAf;

  /// No description provided for @regionTr.
  ///
  /// In en, this message translates to:
  /// **'Turkey'**
  String get regionTr;

  /// No description provided for @regionId.
  ///
  /// In en, this message translates to:
  /// **'Indonesia'**
  String get regionId;

  /// No description provided for @regionBr.
  ///
  /// In en, this message translates to:
  /// **'Brazil'**
  String get regionBr;

  /// No description provided for @regionNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get regionNone;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @dataFolder.
  ///
  /// In en, this message translates to:
  /// **'Data folder'**
  String get dataFolder;

  /// No description provided for @openFolder.
  ///
  /// In en, this message translates to:
  /// **'Open folder'**
  String get openFolder;

  /// No description provided for @unofficialNote.
  ///
  /// In en, this message translates to:
  /// **'Unofficial client. Not affiliated with Mozilla.'**
  String get unofficialNote;

  /// No description provided for @closeTitle.
  ///
  /// In en, this message translates to:
  /// **'Close the window?'**
  String get closeTitle;

  /// No description provided for @closeBody.
  ///
  /// In en, this message translates to:
  /// **'In the tray, the VPN stays connected. Quitting turns it off.'**
  String get closeBody;

  /// No description provided for @rememberChoice.
  ///
  /// In en, this message translates to:
  /// **'Remember my choice'**
  String get rememberChoice;

  /// No description provided for @minimizeToTray.
  ///
  /// In en, this message translates to:
  /// **'Minimize to tray'**
  String get minimizeToTray;

  /// No description provided for @quit.
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get quit;

  /// No description provided for @trayOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get trayOpen;

  /// No description provided for @trayQuit.
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get trayQuit;

  /// No description provided for @trayProxyOnly.
  ///
  /// In en, this message translates to:
  /// **'Proxy service only'**
  String get trayProxyOnly;

  /// No description provided for @traySetSystemProxy.
  ///
  /// In en, this message translates to:
  /// **'Set system proxy'**
  String get traySetSystemProxy;

  /// No description provided for @errPortInUse.
  ///
  /// In en, this message translates to:
  /// **'Port {port} is used by another program, so the app cannot reach its core.'**
  String errPortInUse(String port);

  /// No description provided for @proxyPortInUse.
  ///
  /// In en, this message translates to:
  /// **'Port {port} is used by another program, so the proxy cannot start.'**
  String proxyPortInUse(String port);

  /// No description provided for @changePort.
  ///
  /// In en, this message translates to:
  /// **'Change port'**
  String get changePort;

  /// No description provided for @portDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a port'**
  String get portDialogTitle;

  /// No description provided for @portDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Port {port} is taken. A free port is suggested below; you can type another one.'**
  String portDialogBody(String port);

  /// No description provided for @portChangeBody.
  ///
  /// In en, this message translates to:
  /// **'Apps connect to this port. Choose one from 1024 to 65535.'**
  String get portChangeBody;

  /// No description provided for @portLabel.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get portLabel;

  /// No description provided for @portInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a port from 1024 to 65535'**
  String get portInvalid;

  /// No description provided for @portBusy.
  ///
  /// In en, this message translates to:
  /// **'This port is in use too'**
  String get portBusy;

  /// No description provided for @portInUse.
  ///
  /// In en, this message translates to:
  /// **'Another program uses this port'**
  String get portInUse;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @proxyPort.
  ///
  /// In en, this message translates to:
  /// **'Proxy port'**
  String get proxyPort;

  /// No description provided for @appPort.
  ///
  /// In en, this message translates to:
  /// **'App port'**
  String get appPort;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcomeTitle;

  /// No description provided for @welcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Choose your language and your country. Sites of your country open directly, without the VPN, which is faster and saves quota.'**
  String get welcomeBody;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @routingSuggestTitle.
  ///
  /// In en, this message translates to:
  /// **'Route {country} directly?'**
  String routingSuggestTitle(String country);

  /// No description provided for @routingSuggestBody.
  ///
  /// In en, this message translates to:
  /// **'Sites and IPs of {country} would open directly, without the VPN. You can change this in Routing.'**
  String routingSuggestBody(String country);

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @navServers.
  ///
  /// In en, this message translates to:
  /// **'Servers'**
  String get navServers;

  /// No description provided for @navLogs.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get navLogs;

  /// No description provided for @realDelay.
  ///
  /// In en, this message translates to:
  /// **'Real delay'**
  String get realDelay;

  /// No description provided for @noticePort.
  ///
  /// In en, this message translates to:
  /// **'Mozilla\'s proxy does not connect to port {port}. Only ports 80, 443, 8080 and 8443 go through the VPN.'**
  String noticePort(String port);

  /// No description provided for @noticeCommand.
  ///
  /// In en, this message translates to:
  /// **'An app asked for UDP (games, voice and video calls). Mozilla\'s proxy carries TCP only, so it cannot go through.'**
  String get noticeCommand;

  /// No description provided for @noticeTimes.
  ///
  /// In en, this message translates to:
  /// **'{count} times, last {time}'**
  String noticeTimes(int count, String time);

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @modeRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get modeRecommended;

  /// No description provided for @modeFastest.
  ///
  /// In en, this message translates to:
  /// **'Fastest'**
  String get modeFastest;

  /// No description provided for @modeRecommendedHint.
  ///
  /// In en, this message translates to:
  /// **'Mozilla picks the location for you.'**
  String get modeRecommendedHint;

  /// No description provided for @modeFastestHint.
  ///
  /// In en, this message translates to:
  /// **'The location with the lowest delay at each connection.'**
  String get modeFastestHint;

  /// No description provided for @testDelay.
  ///
  /// In en, this message translates to:
  /// **'Test real delay'**
  String get testDelay;

  /// No description provided for @testingDelay.
  ///
  /// In en, this message translates to:
  /// **'Testing… this can take a minute'**
  String get testingDelay;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @noAnswer.
  ///
  /// In en, this message translates to:
  /// **'No answer'**
  String get noAnswer;

  /// No description provided for @testedAgo.
  ///
  /// In en, this message translates to:
  /// **'Tested {ago}'**
  String testedAgo(String ago);

  /// No description provided for @delaySummary.
  ///
  /// In en, this message translates to:
  /// **'{answered} of {total} answered'**
  String delaySummary(int answered, int total);

  /// No description provided for @noServers.
  ///
  /// In en, this message translates to:
  /// **'No servers yet. They appear once the core reaches Mozilla.'**
  String get noServers;

  /// No description provided for @levelAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get levelAll;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @follow.
  ///
  /// In en, this message translates to:
  /// **'Auto-scroll'**
  String get follow;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @copyAll.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copyAll;

  /// No description provided for @logsCopied.
  ///
  /// In en, this message translates to:
  /// **'Logs copied'**
  String get logsCopied;

  /// No description provided for @noLogs.
  ///
  /// In en, this message translates to:
  /// **'No log lines yet.'**
  String get noLogs;

  /// No description provided for @sectionAccounts.
  ///
  /// In en, this message translates to:
  /// **'Account switching'**
  String get sectionAccounts;

  /// No description provided for @switchThreshold.
  ///
  /// In en, this message translates to:
  /// **'Switch account at'**
  String get switchThreshold;

  /// No description provided for @switchThresholdHint.
  ///
  /// In en, this message translates to:
  /// **'The next account takes over when this share of the quota is used.'**
  String get switchThresholdHint;

  /// No description provided for @sectionDns.
  ///
  /// In en, this message translates to:
  /// **'DNS'**
  String get sectionDns;

  /// No description provided for @dnsPreset.
  ///
  /// In en, this message translates to:
  /// **'DNS servers'**
  String get dnsPreset;

  /// No description provided for @dnsSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get dnsSystem;

  /// No description provided for @dnsAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto (Cloudflare, Google, Quad9)'**
  String get dnsAuto;

  /// No description provided for @dnsCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get dnsCustom;

  /// No description provided for @dnsCustomHint.
  ///
  /// In en, this message translates to:
  /// **'One per line: https://…/dns-query, tls://…, or an IP address.'**
  String get dnsCustomHint;

  /// No description provided for @dnsFallback.
  ///
  /// In en, this message translates to:
  /// **'Fall back to the system DNS'**
  String get dnsFallback;

  /// No description provided for @testDns.
  ///
  /// In en, this message translates to:
  /// **'Test DNS'**
  String get testDns;

  /// No description provided for @transport.
  ///
  /// In en, this message translates to:
  /// **'Protocol'**
  String get transport;

  /// No description provided for @transportH3.
  ///
  /// In en, this message translates to:
  /// **'HTTP/3 (QUIC)'**
  String get transportH3;

  /// No description provided for @transportH2.
  ///
  /// In en, this message translates to:
  /// **'HTTP/2 (TCP)'**
  String get transportH2;

  /// No description provided for @directRules.
  ///
  /// In en, this message translates to:
  /// **'Direct'**
  String get directRules;

  /// No description provided for @directRulesHint.
  ///
  /// In en, this message translates to:
  /// **'Sites and addresses in this list open without the VPN, straight through your own internet. The chosen country\'s rules are already here: add, change, or remove lines. Choosing another country replaces them with its own.'**
  String get directRulesHint;

  /// No description provided for @restoreRegionRules.
  ///
  /// In en, this message translates to:
  /// **'Restore the region\'s rules'**
  String get restoreRegionRules;

  /// No description provided for @blockRules.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get blockRules;

  /// No description provided for @blockRulesHint.
  ///
  /// In en, this message translates to:
  /// **'Sites and addresses in this list do not open at all, neither directly nor through the VPN: for ads, or sites you never want reached.'**
  String get blockRulesHint;

  /// No description provided for @rulesTitle.
  ///
  /// In en, this message translates to:
  /// **'Rules'**
  String get rulesTitle;

  /// No description provided for @ruleSyntaxTitle.
  ///
  /// In en, this message translates to:
  /// **'How to write a rule'**
  String get ruleSyntaxTitle;

  /// No description provided for @resolveDomains.
  ///
  /// In en, this message translates to:
  /// **'Look up names for IP rules'**
  String get resolveDomains;

  /// No description provided for @routingLists.
  ///
  /// In en, this message translates to:
  /// **'Geo files'**
  String get routingLists;

  /// No description provided for @listSource.
  ///
  /// In en, this message translates to:
  /// **'List source'**
  String get listSource;

  /// No description provided for @listSourceCustom.
  ///
  /// In en, this message translates to:
  /// **'Set by hand'**
  String get listSourceCustom;

  /// No description provided for @listsUpdatedAgo.
  ///
  /// In en, this message translates to:
  /// **'Updated {ago}'**
  String listsUpdatedAgo(String ago);

  /// No description provided for @updateLists.
  ///
  /// In en, this message translates to:
  /// **'Update the geo files'**
  String get updateLists;

  /// No description provided for @listsUpdated.
  ///
  /// In en, this message translates to:
  /// **'The geo files were updated.'**
  String get listsUpdated;

  /// No description provided for @testDestination.
  ///
  /// In en, this message translates to:
  /// **'Test a destination'**
  String get testDestination;

  /// No description provided for @destinationHint.
  ///
  /// In en, this message translates to:
  /// **'A name, an address, or a URL'**
  String get destinationHint;

  /// No description provided for @check.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get check;

  /// No description provided for @routeDirect.
  ///
  /// In en, this message translates to:
  /// **'Goes directly'**
  String get routeDirect;

  /// No description provided for @routeProxy.
  ///
  /// In en, this message translates to:
  /// **'Goes through the VPN'**
  String get routeProxy;

  /// No description provided for @routeBlock.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get routeBlock;

  /// No description provided for @ruleMatched.
  ///
  /// In en, this message translates to:
  /// **'Rule: {rule}'**
  String ruleMatched(String rule);

  /// No description provided for @portRefusedNote.
  ///
  /// In en, this message translates to:
  /// **'Mozilla\'s proxy does not connect to this port.'**
  String get portRefusedNote;

  /// No description provided for @sectionAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get sectionAdvanced;

  /// No description provided for @listenAddress.
  ///
  /// In en, this message translates to:
  /// **'Listen on'**
  String get listenAddress;

  /// No description provided for @listenLocal.
  ///
  /// In en, this message translates to:
  /// **'127.0.0.1 · this device only'**
  String get listenLocal;

  /// No description provided for @listenAll.
  ///
  /// In en, this message translates to:
  /// **'0.0.0.0 · all networks (LAN)'**
  String get listenAll;

  /// No description provided for @proxyUsername.
  ///
  /// In en, this message translates to:
  /// **'Proxy username'**
  String get proxyUsername;

  /// No description provided for @proxyPassword.
  ///
  /// In en, this message translates to:
  /// **'Proxy password'**
  String get proxyPassword;

  /// No description provided for @proxyLoginHint.
  ///
  /// In en, this message translates to:
  /// **'Apps must sign in with these. Leave both empty for no login.'**
  String get proxyLoginHint;

  /// No description provided for @loginBothOrNone.
  ///
  /// In en, this message translates to:
  /// **'Fill in both, or leave both empty.'**
  String get loginBothOrNone;

  /// No description provided for @proxyLogin.
  ///
  /// In en, this message translates to:
  /// **'Proxy login'**
  String get proxyLogin;

  /// No description provided for @idleSleep.
  ///
  /// In en, this message translates to:
  /// **'Sleep when idle after'**
  String get idleSleep;

  /// No description provided for @sleepNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get sleepNever;

  /// No description provided for @sleepMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count} minutes'**
  String sleepMinutes(int count);

  /// No description provided for @sleepHour.
  ///
  /// In en, this message translates to:
  /// **'1 hour'**
  String get sleepHour;

  /// No description provided for @showPublicIp.
  ///
  /// In en, this message translates to:
  /// **'Show the public IP'**
  String get showPublicIp;

  /// No description provided for @speedInNotification.
  ///
  /// In en, this message translates to:
  /// **'Show speed in the notification'**
  String get speedInNotification;

  /// No description provided for @liveTraffic.
  ///
  /// In en, this message translates to:
  /// **'Live traffic'**
  String get liveTraffic;

  /// No description provided for @totalTraffic.
  ///
  /// In en, this message translates to:
  /// **'Total traffic'**
  String get totalTraffic;

  /// No description provided for @verboseLogs.
  ///
  /// In en, this message translates to:
  /// **'Detailed logs'**
  String get verboseLogs;

  /// No description provided for @webDashboard.
  ///
  /// In en, this message translates to:
  /// **'Web dashboard'**
  String get webDashboard;

  /// No description provided for @webDashboardOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get webDashboardOpen;

  /// No description provided for @webDashboardHint.
  ///
  /// In en, this message translates to:
  /// **'Advanced settings and more tools'**
  String get webDashboardHint;

  /// No description provided for @numberInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a number from {min} to {max}'**
  String numberInvalid(int min, int max);

  /// No description provided for @notifySwitchedTitle.
  ///
  /// In en, this message translates to:
  /// **'Switched account'**
  String get notifySwitchedTitle;

  /// No description provided for @notifySwitchedBody.
  ///
  /// In en, this message translates to:
  /// **'Now using {name}.'**
  String notifySwitchedBody(String name);

  /// No description provided for @notifySignInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign-in needed'**
  String get notifySignInTitle;

  /// No description provided for @notifySignInBody.
  ///
  /// In en, this message translates to:
  /// **'An account must be signed in again on the Accounts page.'**
  String get notifySignInBody;

  /// No description provided for @navAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get navAbout;

  /// No description provided for @appVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'App version'**
  String get appVersionLabel;

  /// No description provided for @coreVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Core version'**
  String get coreVersionLabel;

  /// No description provided for @checkUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get checkUpdates;

  /// No description provided for @checkingUpdates.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get checkingUpdates;

  /// No description provided for @upToDate.
  ///
  /// In en, this message translates to:
  /// **'You have the latest version.'**
  String get upToDate;

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is available.'**
  String updateAvailable(String version);

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @updateCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not check for updates: {error}'**
  String updateCheckFailed(String error);

  /// No description provided for @repoNotSet.
  ///
  /// In en, this message translates to:
  /// **'The GitHub repository is not set yet.'**
  String get repoNotSet;

  /// No description provided for @sourceCode.
  ///
  /// In en, this message translates to:
  /// **'Source code'**
  String get sourceCode;

  /// No description provided for @tapToConnect.
  ///
  /// In en, this message translates to:
  /// **'Click to connect'**
  String get tapToConnect;

  /// No description provided for @tapToDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Click to disconnect'**
  String get tapToDisconnect;

  /// No description provided for @startOnBoot.
  ///
  /// In en, this message translates to:
  /// **'Start on boot'**
  String get startOnBoot;

  /// No description provided for @connectOnStartup.
  ///
  /// In en, this message translates to:
  /// **'Connect on startup'**
  String get connectOnStartup;

  /// No description provided for @proxyServiceActive.
  ///
  /// In en, this message translates to:
  /// **'Proxy service active'**
  String get proxyServiceActive;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @groupApp.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get groupApp;

  /// No description provided for @stateOff.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get stateOff;

  /// No description provided for @tapToConnectPhone.
  ///
  /// In en, this message translates to:
  /// **'Tap to connect'**
  String get tapToConnectPhone;

  /// No description provided for @tapToDisconnectPhone.
  ///
  /// In en, this message translates to:
  /// **'Tap to disconnect'**
  String get tapToDisconnectPhone;

  /// No description provided for @lanAddress.
  ///
  /// In en, this message translates to:
  /// **'LAN {address}'**
  String lanAddress(String address);

  /// No description provided for @recommendedLocation.
  ///
  /// In en, this message translates to:
  /// **'Recommended location'**
  String get recommendedLocation;

  /// No description provided for @dataLeftOf.
  ///
  /// In en, this message translates to:
  /// **'of {limit}'**
  String dataLeftOf(String limit);

  /// No description provided for @homeLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get homeLocation;

  /// No description provided for @connectedTo.
  ///
  /// In en, this message translates to:
  /// **'Connected to'**
  String get connectedTo;

  /// No description provided for @vpnNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'The VPN needs your permission. Tap the button again and allow it.'**
  String get vpnNotAllowed;

  /// No description provided for @dataUsedTitle.
  ///
  /// In en, this message translates to:
  /// **'Data used'**
  String get dataUsedTitle;

  /// No description provided for @bypassApps.
  ///
  /// In en, this message translates to:
  /// **'Per-app proxy'**
  String get bypassApps;

  /// No description provided for @connectRetrying.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t connect. Check your internet.'**
  String get connectRetrying;

  /// No description provided for @failUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Mozilla\'s servers are blocked on this internet. Try another internet connection.'**
  String get failUnreachable;

  /// No description provided for @failRefused.
  ///
  /// In en, this message translates to:
  /// **'Mozilla\'s server refused the connection. Try again in a few minutes.'**
  String get failRefused;

  /// No description provided for @failLocationRefused.
  ///
  /// In en, this message translates to:
  /// **'This country isn\'t open to your account. Choose another country.'**
  String get failLocationRefused;

  /// No description provided for @useRecommendedLocation.
  ///
  /// In en, this message translates to:
  /// **'Use the recommended location'**
  String get useRecommendedLocation;

  /// No description provided for @exitMismatch.
  ///
  /// In en, this message translates to:
  /// **'You chose {chosen}, but your IP is in {exit}.'**
  String exitMismatch(String exit, String chosen);

  /// No description provided for @failSignIn.
  ///
  /// In en, this message translates to:
  /// **'This account\'s sign-in has expired. Sign in again on the Accounts page.'**
  String get failSignIn;

  /// No description provided for @failQuota.
  ///
  /// In en, this message translates to:
  /// **'This month\'s data is used up. Add another account.'**
  String get failQuota;

  /// No description provided for @failNotEntitled.
  ///
  /// In en, this message translates to:
  /// **'Mozilla doesn\'t let this account use the VPN. Add another account.'**
  String get failNotEntitled;

  /// No description provided for @failRegion.
  ///
  /// In en, this message translates to:
  /// **'Mozilla doesn\'t offer its service in your country.'**
  String get failRegion;

  /// No description provided for @failServer.
  ///
  /// In en, this message translates to:
  /// **'Mozilla\'s service has a temporary problem. The app tries again by itself.'**
  String get failServer;

  /// No description provided for @failNoAccount.
  ///
  /// In en, this message translates to:
  /// **'No account is ready. Open the Accounts page.'**
  String get failNoAccount;

  /// No description provided for @failTestSite.
  ///
  /// In en, this message translates to:
  /// **'Connected to the server, but sites don\'t open. Try another country.'**
  String get failTestSite;

  /// No description provided for @failOther.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t connect. Try again.'**
  String get failOther;

  /// No description provided for @failNoInternet.
  ///
  /// In en, this message translates to:
  /// **'No internet. Check Wi-Fi or mobile data.'**
  String get failNoInternet;

  /// The home page while the core waits for a network before connecting (state code waiting_for_network).
  ///
  /// In en, this message translates to:
  /// **'Waiting for an internet connection…'**
  String get waitingForNetwork;

  /// The home page after the proxy failed to start on its port for a reason other than another program holding it, such as a port Windows reserves (state code start_failed), with a Change port button.
  ///
  /// In en, this message translates to:
  /// **'The proxy couldn\'t start on port {port}. Choose another port.'**
  String proxyStartFailed(String port);

  /// No description provided for @connectionSettings.
  ///
  /// In en, this message translates to:
  /// **'Connection settings'**
  String get connectionSettings;

  /// No description provided for @appModeExclude.
  ///
  /// In en, this message translates to:
  /// **'Bypass selected apps'**
  String get appModeExclude;

  /// No description provided for @appModeInclude.
  ///
  /// In en, this message translates to:
  /// **'Proxy selected apps'**
  String get appModeInclude;

  /// No description provided for @appModeExcludeHint.
  ///
  /// In en, this message translates to:
  /// **'Selected apps connect directly, not through the VPN: for example banking apps that refuse foreign addresses.'**
  String get appModeExcludeHint;

  /// No description provided for @appModeIncludeHint.
  ///
  /// In en, this message translates to:
  /// **'Only the selected apps go through the VPN; the others connect directly.'**
  String get appModeIncludeHint;

  /// No description provided for @fromRegionList.
  ///
  /// In en, this message translates to:
  /// **'Suggested: on the {region} list'**
  String fromRegionList(String region);

  /// No description provided for @modeProxy.
  ///
  /// In en, this message translates to:
  /// **'Proxy'**
  String get modeProxy;

  /// No description provided for @connectionMode.
  ///
  /// In en, this message translates to:
  /// **'Connection mode'**
  String get connectionMode;

  /// No description provided for @modeProxyHint.
  ///
  /// In en, this message translates to:
  /// **'Only apps set up to use the proxy go through it; Windows is left as it is.'**
  String get modeProxyHint;

  /// No description provided for @modeSystemProxyHint.
  ///
  /// In en, this message translates to:
  /// **'Windows and most apps go through the proxy.'**
  String get modeSystemProxyHint;

  /// No description provided for @modeProxyHintOther.
  ///
  /// In en, this message translates to:
  /// **'Only apps set up to use the proxy go through it; the system\'s settings stay as they are.'**
  String get modeProxyHintOther;

  /// No description provided for @modeSystemProxyHintOther.
  ///
  /// In en, this message translates to:
  /// **'Browsers and most apps go through the proxy.'**
  String get modeSystemProxyHintOther;

  /// No description provided for @suggestedApps.
  ///
  /// In en, this message translates to:
  /// **'Suggested apps'**
  String get suggestedApps;

  /// No description provided for @suggestedAdded.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{The suggested apps are already selected} =1{1 suggested app selected} other{{count} suggested apps selected}}'**
  String suggestedAdded(int count);

  /// No description provided for @autoSection.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get autoSection;

  /// No description provided for @locationsSection.
  ///
  /// In en, this message translates to:
  /// **'Locations'**
  String get locationsSection;

  /// No description provided for @dnsSummaryOk.
  ///
  /// In en, this message translates to:
  /// **'Encrypted DNS works'**
  String get dnsSummaryOk;

  /// No description provided for @dnsSummaryFailed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 name did not resolve} other{{count} names did not resolve}}'**
  String dnsSummaryFailed(int count);

  /// No description provided for @dnsVia.
  ///
  /// In en, this message translates to:
  /// **'via {server}'**
  String dnsVia(String server);

  /// No description provided for @dnsSummaryDiffers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Your network\'s DNS answered 1 name with a filtering address. This app does not use it for them.} other{Your network\'s DNS answered {count} names with a filtering address. This app does not use it for them.}}'**
  String dnsSummaryDiffers(int count);

  /// No description provided for @dnsAnswer.
  ///
  /// In en, this message translates to:
  /// **'Answer:'**
  String get dnsAnswer;

  /// No description provided for @dnsNetworkAnswer.
  ///
  /// In en, this message translates to:
  /// **'Network DNS:'**
  String get dnsNetworkAnswer;

  /// No description provided for @dnsFiltered.
  ///
  /// In en, this message translates to:
  /// **'filtered'**
  String get dnsFiltered;

  /// No description provided for @rulesSyntaxTitle.
  ///
  /// In en, this message translates to:
  /// **'One rule per line'**
  String get rulesSyntaxTitle;

  /// No description provided for @ruleDomain.
  ///
  /// In en, this message translates to:
  /// **'The site and its subdomains'**
  String get ruleDomain;

  /// No description provided for @ruleFull.
  ///
  /// In en, this message translates to:
  /// **'Exactly this name'**
  String get ruleFull;

  /// No description provided for @ruleKeyword.
  ///
  /// In en, this message translates to:
  /// **'Names that contain the word'**
  String get ruleKeyword;

  /// No description provided for @ruleGeosite.
  ///
  /// In en, this message translates to:
  /// **'Sites of a tag in the geo files'**
  String get ruleGeosite;

  /// No description provided for @ruleGeoip.
  ///
  /// In en, this message translates to:
  /// **'Addresses of a country in the geo files'**
  String get ruleGeoip;

  /// No description provided for @ruleIp.
  ///
  /// In en, this message translates to:
  /// **'An address or a network'**
  String get ruleIp;

  /// Phone connection mode: every app on the phone goes through the VPN.
  ///
  /// In en, this message translates to:
  /// **'VPN'**
  String get modeVpn;

  /// Phone connection mode: no VPN; only apps set up to use the local proxy. Also shown before the proxy address on the home page.
  ///
  /// In en, this message translates to:
  /// **'Proxy only'**
  String get modeProxyOnly;

  /// Shown at once, in red, when the phone has neither Wi-Fi nor mobile data.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Turn on Wi-Fi or mobile data.'**
  String get noNetwork;

  /// No description provided for @blockAds.
  ///
  /// In en, this message translates to:
  /// **'Block ads'**
  String get blockAds;

  /// The home page when another program (another VPN or proxy) replaced the system proxy the app set (status system_proxy_taken).
  ///
  /// In en, this message translates to:
  /// **'Another program set the system proxy to {address}, so traffic doesn\'t go through the VPN.'**
  String systemProxyTakenBy(String address);

  /// No description provided for @systemProxyTakenOff.
  ///
  /// In en, this message translates to:
  /// **'Another program turned the system proxy off, so traffic doesn\'t go through the VPN.'**
  String get systemProxyTakenOff;

  /// No description provided for @setSystemProxyAgain.
  ///
  /// In en, this message translates to:
  /// **'Set it again'**
  String get setSystemProxyAgain;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'az',
    'bn',
    'en',
    'es',
    'fa',
    'fr',
    'hu',
    'id',
    'pt',
    'ru',
    'tr',
    'vi',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'Hant':
            return AppLocalizationsZhHant();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'az':
      return AppLocalizationsAz();
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fa':
      return AppLocalizationsFa();
    case 'fr':
      return AppLocalizationsFr();
    case 'hu':
      return AppLocalizationsHu();
    case 'id':
      return AppLocalizationsId();
    case 'pt':
      return AppLocalizationsPt();
    case 'ru':
      return AppLocalizationsRu();
    case 'tr':
      return AppLocalizationsTr();
    case 'vi':
      return AppLocalizationsVi();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
