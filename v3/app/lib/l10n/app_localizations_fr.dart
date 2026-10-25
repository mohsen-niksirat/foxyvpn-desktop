// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Firefox VPN';

  @override
  String get navOverview => 'Aperçu';

  @override
  String get navAccounts => 'Comptes';

  @override
  String get navSettings => 'Paramètres';

  @override
  String get stateConnected => 'Connecté';

  @override
  String get stateConnecting => 'Connexion…';

  @override
  String get stateWaiting => 'En attente';

  @override
  String get waitingForAccount =>
      'Ajoutez un Firefox Account sur la page Comptes pour vous connecter.';

  @override
  String get waitingForEnabledAccount =>
      'Tous les comptes sont désactivés. Activez-en un sur la page Comptes.';

  @override
  String get stateError => 'Erreur';

  @override
  String get stateUnknown => 'Inconnu';

  @override
  String get restartProxy => 'Redémarrer le proxy';

  @override
  String copied(String value) {
    return '$value copié';
  }

  @override
  String get activeAccount => 'Compte actif';

  @override
  String get noActiveAccount => 'Aucun compte actif';

  @override
  String get quotaNotRead => 'Consommation pas encore vérifiée';

  @override
  String get unlimited => 'Illimité';

  @override
  String usedOf(String used, String limit) {
    return '$used utilisés sur $limit';
  }

  @override
  String resets(String date) {
    return 'remise à zéro le $date';
  }

  @override
  String switchAt(int percent) {
    return 'Changement de compte à $percent %';
  }

  @override
  String get publicIp => 'IP publique';

  @override
  String get testConnection => 'Tester la connexion';

  @override
  String get testing => 'Test en cours…';

  @override
  String get testFailed => 'Échec';

  @override
  String milliseconds(int value) {
    return '$value ms';
  }

  @override
  String get justNow => 'à l\'instant';

  @override
  String minutesAgo(int n) {
    return 'il y a $n min';
  }

  @override
  String hoursAgo(int n) {
    return 'il y a $n h';
  }

  @override
  String daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count jours',
      one: 'il y a 1 jour',
    );
    return '$_temp0';
  }

  @override
  String atTime(String time) {
    return 'à $time';
  }

  @override
  String durationDays(int d, int h) {
    return '$d j $h h';
  }

  @override
  String durationHours(int h, int m) {
    return '$h h $m min';
  }

  @override
  String durationMinutes(int m, int s) {
    return '$m min $s s';
  }

  @override
  String durationSeconds(int s) {
    return '$s s';
  }

  @override
  String accountsGuide(String size) {
    return 'Chaque Firefox Account dispose de $size de données par mois. Vous pouvez en ajouter plusieurs : quand l’un est épuisé, l’application passe d’elle-même au suivant.';
  }

  @override
  String accountsOrderNote(int percent) {
    return 'Dans l’ordre de cette liste : chacun jusqu’à $percent %, le dernier jusqu’à épuisement de ses données.';
  }

  @override
  String get addAccount => 'Ajouter un compte';

  @override
  String lowQuotaNotice(String left, String size) {
    return 'Les données du compte actuel sont presque épuisées ($left restants). Ajoutez un autre compte pour obtenir $size de plus.';
  }

  @override
  String get noAccounts => 'Aucun compte pour l\'instant';

  @override
  String get noAccountsHint =>
      'Ajoutez un Firefox Account pour vous connecter.';

  @override
  String get createAccountTitle => 'Pas de Firefox Account ?';

  @override
  String get createAccountHint =>
      'Créez-en un gratuitement sur accounts.firefox.com, puis revenez et appuyez sur Ajouter un compte.';

  @override
  String get moveUp => 'Monter';

  @override
  String get moveDown => 'Descendre';

  @override
  String get statusActive => 'Actif';

  @override
  String get statusReady => 'Prêt';

  @override
  String get statusNeedsSignIn => 'Reconnexion requise';

  @override
  String get statusReserved => 'Réservé';

  @override
  String get statusUnavailable => 'Indisponible';

  @override
  String statusUnavailableUntil(String date) {
    return 'Indisponible jusqu\'au $date';
  }

  @override
  String get statusDisabled => 'Désactivé';

  @override
  String get statusEnabled => 'Activé';

  @override
  String get useNow => 'Utiliser maintenant';

  @override
  String get signInAgain => 'Se reconnecter';

  @override
  String reasonQuotaThreshold(int percent) {
    return 'Ce compte a utilisé $percent % de ses données ; le compte suivant a pris le relais.';
  }

  @override
  String get reasonQuotaExhausted =>
      'Les données du mois sont épuisées ; il sera réutilisé après la remise à zéro mensuelle.';

  @override
  String get reasonSignInRequired =>
      'Reconnectez-vous pour utiliser ce compte.';

  @override
  String get reasonSignInConfirm =>
      'Mozilla demande de confirmer la connexion : appuyez sur « Se reconnecter » (seul le code est nécessaire).';

  @override
  String reasonSignInFailed(String detail) {
    return 'La connexion automatique a échoué ($detail). Reconnectez-vous.';
  }

  @override
  String reasonSignInWait(String time) {
    return 'La dernière connexion automatique a cessé de fonctionner peu après ; prochain essai à $time.';
  }

  @override
  String reasonSignInRetry(String detail, String time) {
    return 'La connexion automatique n’a pas abouti ($detail) ; nouvel essai à $time.';
  }

  @override
  String get reasonNotEntitled =>
      'Mozilla a refusé ce compte ; nouvel essai plus tard.';

  @override
  String get more => 'Plus';

  @override
  String get refreshQuota => 'Actualiser la consommation';

  @override
  String get remove => 'Supprimer';

  @override
  String get removeTitle => 'Supprimer le compte ?';

  @override
  String removeBody(String name) {
    return '$name et ses identifiants enregistrés seront supprimés de cet appareil. Vous pourrez l\'ajouter à nouveau plus tard.';
  }

  @override
  String get unlimitedQuota => 'Données illimitées';

  @override
  String get signInTitle => 'Connexion au compte';

  @override
  String get signInIntro => 'Connectez-vous avec un Firefox Account.';

  @override
  String get email => 'E-mail';

  @override
  String get emailInvalid => 'Saisissez l\'e-mail du compte';

  @override
  String get password => 'Mot de passe';

  @override
  String get passwordEmpty => 'Saisissez le mot de passe';

  @override
  String get show => 'Afficher';

  @override
  String get hide => 'Masquer';

  @override
  String get signIn => 'Se connecter';

  @override
  String get continueLabel => 'Continuer';

  @override
  String get done => 'Terminé';

  @override
  String get close => 'Fermer';

  @override
  String get cancel => 'Annuler';

  @override
  String get tryAgain => 'Réessayer';

  @override
  String get signingIn => 'Connexion au compte…';

  @override
  String get accountReady => 'Compte prêt';

  @override
  String get accountReadyHint => 'Il a été ajouté en fin de liste.';

  @override
  String get captchaLabel => 'Caractères de l\'image';

  @override
  String get codeLabel => 'Code';

  @override
  String get captchaBroken => 'L\'image CAPTCHA n\'a pas pu être affichée.';

  @override
  String stepEmailCode(String email) {
    return 'Mozilla a envoyé un code à $email. Saisissez-le ici.';
  }

  @override
  String get stepTotp =>
      'Saisissez le code de votre application d\'authentification.';

  @override
  String stepUnblockCode(String email) {
    return 'Mozilla juge cette connexion inhabituelle et a envoyé un code de déblocage à $email. Saisissez-le ici.';
  }

  @override
  String get stepCaptcha => 'Tapez les caractères de l\'image.';

  @override
  String stepEmailLink(String email) {
    return 'Ouvrez le lien de confirmation envoyé par Mozilla à $email. La suite se fait automatiquement.';
  }

  @override
  String get signInFailed => 'Le compte n\'a pas été ajouté.';

  @override
  String get signInCancelled => 'Connexion annulée.';

  @override
  String get signInNoAccount =>
      'Aucun Firefox Account n\'existe pour cette adresse.';

  @override
  String get signInNoAccountHint =>
      'Vérifiez l\'adresse, ou créez avec elle un Firefox Account gratuit sur le site de Mozilla, confirmez-le depuis votre boîte de réception, puis ajoutez-le ici.';

  @override
  String get createAccountButton => 'Créer un Firefox Account';

  @override
  String get signInWrongPassword => 'Mot de passe incorrect.';

  @override
  String get signInNoPassword =>
      'Ce compte n\'a pas de mot de passe : il a été créé avec la connexion Google ou Apple. Définissez un mot de passe, puis connectez-vous ici avec.';

  @override
  String get setPasswordButton => 'Définir un mot de passe';

  @override
  String get signInTooManyAttempts =>
      'Trop de tentatives. Patientez un peu, puis réessayez.';

  @override
  String get signInUnblockRejected =>
      'Le code de déblocage n\'a pas été accepté. Utilisez le code du dernier e-mail de Mozilla.';

  @override
  String get signInWrongCode =>
      'Code incorrect ou expiré. Utilisez le code du dernier e-mail de Mozilla ; un ancien code ne fonctionne plus dès qu\'un nouveau est envoyé.';

  @override
  String get signInWrongTotp =>
      'Code incorrect. Saisissez le code que l\'application d\'authentification affiche maintenant.';

  @override
  String get signInTooManyCodes =>
      'Trop de codes incorrects. Recommencez la connexion.';

  @override
  String get signInTimedOut =>
      'La connexion a pris trop de temps. Recommencez.';

  @override
  String get signInNetwork =>
      'Impossible de joindre Mozilla. Vérifiez votre accès à Internet et réessayez.';

  @override
  String get coreConnecting => 'Connexion au moteur…';

  @override
  String get coreLost => 'Connexion au moteur perdue. Nouvelle tentative…';

  @override
  String get cantReachCore => 'Impossible de joindre le moteur';

  @override
  String get startingCore => 'Démarrage du moteur…';

  @override
  String get retry => 'Réessayer';

  @override
  String errNoCore(String path) {
    return 'Le moteur est introuvable dans le dossier de l\'application ($path).';
  }

  @override
  String errCoreExited(String detail) {
    return 'Le moteur s\'est arrêté : $detail';
  }

  @override
  String get errNotAnswering => 'Le moteur ne répond pas.';

  @override
  String get errRefused =>
      'Le moteur a refusé l\'application ; il appartient peut-être à une autre installation.';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get sectionGeneral => 'Général';

  @override
  String get language => 'Langue';

  @override
  String get languageSystem => 'Langue du système';

  @override
  String get theme => 'Thème';

  @override
  String get themeSystem => 'Système';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

  @override
  String get closeBehavior => 'À la fermeture de la fenêtre';

  @override
  String get closeAsk => 'Toujours demander';

  @override
  String get closeTray => 'Réduire dans la zone de notification';

  @override
  String get closeQuit => 'Quitter l\'application';

  @override
  String get sectionConnection => 'Connexion';

  @override
  String get localProxy => 'Proxy local';

  @override
  String get systemProxy => 'Proxy système';

  @override
  String get sectionRouting => 'Routage';

  @override
  String get routingDirect => 'Connexion directe pour les sites locaux';

  @override
  String get routingDirectHint =>
      'Les sites et IP du pays choisi contournent le VPN : ils s\'ouvrent plus vite et vous économisez des données.';

  @override
  String get region => 'Pays';

  @override
  String get regionIr => 'Iran';

  @override
  String get regionCn => 'Chine';

  @override
  String get regionRu => 'Russie';

  @override
  String get regionAf => 'Afghanistan';

  @override
  String get regionTr => 'Turquie';

  @override
  String get regionId => 'Indonésie';

  @override
  String get regionBr => 'Brésil';

  @override
  String get regionNone => 'Aucun';

  @override
  String get saved => 'Enregistré';

  @override
  String get dataFolder => 'Dossier de données';

  @override
  String get openFolder => 'Ouvrir le dossier';

  @override
  String get unofficialNote => 'Client non officiel. Non affilié à Mozilla.';

  @override
  String get closeTitle => 'Fermer la fenêtre ?';

  @override
  String get closeBody =>
      'Réduite dans la zone de notification, l\'application garde le VPN connecté. Si vous quittez, le VPN se déconnecte.';

  @override
  String get rememberChoice => 'Mémoriser mon choix';

  @override
  String get minimizeToTray => 'Réduire';

  @override
  String get quit => 'Quitter';

  @override
  String get trayOpen => 'Ouvrir';

  @override
  String get trayQuit => 'Quitter';

  @override
  String get trayProxyOnly => 'Service proxy seul';

  @override
  String get traySetSystemProxy => 'Définir le proxy système';

  @override
  String errPortInUse(String port) {
    return 'Le port $port est utilisé par un autre programme ; l\'application ne peut donc pas joindre son moteur.';
  }

  @override
  String proxyPortInUse(String port) {
    return 'Le port $port est utilisé par un autre programme ; le proxy ne peut donc pas démarrer.';
  }

  @override
  String get changePort => 'Changer de port';

  @override
  String get portDialogTitle => 'Choisir un port';

  @override
  String portDialogBody(String port) {
    return 'Le port $port est occupé. Un port libre est proposé ci-dessous ; vous pouvez en saisir un autre.';
  }

  @override
  String get portChangeBody =>
      'Les applications se connectent à ce port. Choisissez-en un entre 1024 et 65535.';

  @override
  String get portLabel => 'Port';

  @override
  String get portInvalid => 'Saisissez un port entre 1024 et 65535';

  @override
  String get portBusy => 'Ce port est aussi occupé';

  @override
  String get portInUse => 'Un autre programme utilise ce port';

  @override
  String get save => 'Enregistrer';

  @override
  String get proxyPort => 'Port du proxy';

  @override
  String get appPort => 'Port de l\'application';

  @override
  String get welcomeTitle => 'Bienvenue';

  @override
  String get welcomeBody =>
      'Choisissez votre langue et votre pays. Les sites de votre pays s\'ouvrent directement, sans le VPN : c\'est plus rapide et vous économisez des données.';

  @override
  String get start => 'Commencer';

  @override
  String routingSuggestTitle(String country) {
    return 'Connexion directe pour $country ?';
  }

  @override
  String routingSuggestBody(String country) {
    return 'Les sites et IP locaux ($country) s\'ouvriraient directement, sans le VPN. Vous pourrez modifier cela dans Routage.';
  }

  @override
  String get yes => 'Oui';

  @override
  String get notNow => 'Plus tard';

  @override
  String get navServers => 'Serveurs';

  @override
  String get navLogs => 'Journaux';

  @override
  String get realDelay => 'Latence réelle';

  @override
  String noticePort(String port) {
    return 'Le proxy de Mozilla ne se connecte pas au port $port. Seuls les ports 80, 443, 8080 et 8443 passent par le VPN.';
  }

  @override
  String get noticeCommand =>
      'Une application a tenté d\'utiliser l\'UDP (jeux, appels audio et vidéo). Le proxy de Mozilla ne prend en charge que le TCP : cette connexion ne peut pas passer.';

  @override
  String noticeTimes(int count, String time) {
    return '$count fois, la dernière $time';
  }

  @override
  String get dismiss => 'Ignorer';

  @override
  String get modeRecommended => 'Recommandé';

  @override
  String get modeFastest => 'Le plus rapide';

  @override
  String get modeRecommendedHint => 'Mozilla choisit l\'emplacement pour vous.';

  @override
  String get modeFastestHint =>
      'L\'emplacement avec la latence la plus faible à chaque connexion.';

  @override
  String get testDelay => 'Tester la latence réelle';

  @override
  String get testingDelay => 'Test en cours… cela peut prendre une minute';

  @override
  String get search => 'Rechercher';

  @override
  String get noAnswer => 'Pas de réponse';

  @override
  String testedAgo(String ago) {
    return 'Testé $ago';
  }

  @override
  String delaySummary(int answered, int total) {
    return '$answered sur $total ont répondu';
  }

  @override
  String get noServers =>
      'Aucun serveur pour l\'instant. Ils apparaîtront dès que la connexion à Mozilla sera établie.';

  @override
  String get levelAll => 'Tous';

  @override
  String get filter => 'Filtrer';

  @override
  String get follow => 'Défilement auto';

  @override
  String get clear => 'Effacer';

  @override
  String get copyAll => 'Tout copier';

  @override
  String get logsCopied => 'Journaux copiés';

  @override
  String get noLogs => 'Aucune ligne de journal pour l\'instant.';

  @override
  String get sectionAccounts => 'Changement automatique de compte';

  @override
  String get switchThreshold => 'Changer de compte à';

  @override
  String get switchThresholdHint =>
      'Le compte suivant prend le relais lorsque ce pourcentage des données est consommé.';

  @override
  String get sectionDns => 'DNS';

  @override
  String get dnsPreset => 'Serveurs DNS';

  @override
  String get dnsSystem => 'Système';

  @override
  String get dnsAuto => 'Auto (Cloudflare, Google, Quad9)';

  @override
  String get dnsCustom => 'Personnalisé';

  @override
  String get dnsCustomHint =>
      'Un par ligne : https://…/dns-query, tls://… ou une adresse IP.';

  @override
  String get dnsFallback => 'Utiliser le DNS du système en secours';

  @override
  String get testDns => 'Tester le DNS';

  @override
  String get transport => 'Protocole';

  @override
  String get transportH3 => 'HTTP/3 (QUIC)';

  @override
  String get transportH2 => 'HTTP/2 (TCP)';

  @override
  String get directRules => 'Direct';

  @override
  String get directRulesHint =>
      'Les sites et adresses de cette liste s’ouvrent sans le VPN, directement par votre propre connexion. Les règles du pays choisi y sont déjà : ajoutez, modifiez ou supprimez des lignes. Choisir un autre pays les remplace par les siennes.';

  @override
  String get restoreRegionRules => 'Rétablir les règles du pays';

  @override
  String get blockRules => 'Bloquer';

  @override
  String get blockRulesHint =>
      'Les sites et adresses de cette liste ne s’ouvrent pas du tout, ni directement ni par le VPN : pour les publicités ou les sites que vous ne voulez jamais ouvrir.';

  @override
  String get rulesTitle => 'Règles';

  @override
  String get ruleSyntaxTitle => 'Comment écrire une règle';

  @override
  String get resolveDomains => 'Appliquer les règles IP aux domaines';

  @override
  String get routingLists => 'Fichiers Geo';

  @override
  String get listSource => 'Source des listes';

  @override
  String get listSourceCustom => 'Saisie manuelle';

  @override
  String listsUpdatedAgo(String ago) {
    return 'Mis à jour $ago';
  }

  @override
  String get updateLists => 'Mettre à jour les fichiers Geo';

  @override
  String get listsUpdated => 'Les fichiers Geo ont été mis à jour.';

  @override
  String get testDestination => 'Vérifier le routage d\'un site';

  @override
  String get destinationHint => 'Un nom, une adresse ou une URL';

  @override
  String get check => 'Vérifier';

  @override
  String get routeDirect => 'Passe en direct';

  @override
  String get routeProxy => 'Passe par le VPN';

  @override
  String get routeBlock => 'Bloqué';

  @override
  String ruleMatched(String rule) {
    return 'Règle : $rule';
  }

  @override
  String get portRefusedNote =>
      'Le proxy de Mozilla ne se connecte pas à ce port.';

  @override
  String get sectionAdvanced => 'Avancé';

  @override
  String get listenAddress => 'Accès au proxy';

  @override
  String get listenLocal => '127.0.0.1 · cet appareil uniquement';

  @override
  String get listenAll => '0.0.0.0 · tous les réseaux (LAN)';

  @override
  String get proxyUsername => 'Nom d\'utilisateur du proxy';

  @override
  String get proxyPassword => 'Mot de passe du proxy';

  @override
  String get proxyLoginHint =>
      'Les applications doivent s\'identifier avec ces informations. Laissez les deux vides pour ne pas exiger d\'identification.';

  @override
  String get loginBothOrNone =>
      'Remplissez les deux, ou laissez les deux vides.';

  @override
  String get proxyLogin => 'Identifiants du proxy';

  @override
  String get idleSleep => 'Veille après inactivité';

  @override
  String get sleepNever => 'Jamais';

  @override
  String sleepMinutes(int count) {
    return '$count minutes';
  }

  @override
  String get sleepHour => '1 heure';

  @override
  String get showPublicIp => 'Afficher l\'IP publique';

  @override
  String get speedInNotification => 'Afficher la vitesse dans la notification';

  @override
  String get liveTraffic => 'Trafic en direct';

  @override
  String get totalTraffic => 'Trafic total';

  @override
  String get verboseLogs => 'Journaux détaillés';

  @override
  String get webDashboard => 'Tableau de bord web';

  @override
  String get webDashboardOpen => 'Ouvrir';

  @override
  String get webDashboardHint => 'Paramètres avancés et plus d\'outils';

  @override
  String numberInvalid(int min, int max) {
    return 'Saisissez un nombre entre $min et $max';
  }

  @override
  String get notifySwitchedTitle => 'Changement de compte';

  @override
  String notifySwitchedBody(String name) {
    return 'Vous utilisez maintenant $name.';
  }

  @override
  String get notifySignInTitle => 'Reconnexion requise';

  @override
  String get notifySignInBody => 'Reconnectez un compte sur la page Comptes.';

  @override
  String get navAbout => 'À propos';

  @override
  String get appVersionLabel => 'Version de l\'application';

  @override
  String get coreVersionLabel => 'Version du moteur';

  @override
  String get checkUpdates => 'Rechercher des mises à jour';

  @override
  String get checkingUpdates => 'Vérification…';

  @override
  String get upToDate => 'Vous avez la dernière version.';

  @override
  String updateAvailable(String version) {
    return 'La version $version est disponible.';
  }

  @override
  String get download => 'Télécharger';

  @override
  String updateCheckFailed(String error) {
    return 'Impossible de rechercher des mises à jour : $error';
  }

  @override
  String get repoNotSet => 'Le dépôt GitHub n\'est pas encore défini.';

  @override
  String get sourceCode => 'Code source';

  @override
  String get tapToConnect => 'Cliquez pour vous connecter';

  @override
  String get tapToDisconnect => 'Cliquez pour vous déconnecter';

  @override
  String get startOnBoot => 'Lancer au démarrage';

  @override
  String get connectOnStartup => 'Se connecter au démarrage';

  @override
  String get proxyServiceActive => 'Service proxy actif';

  @override
  String get navHome => 'Accueil';

  @override
  String get groupApp => 'Application';

  @override
  String get stateOff => 'Déconnecté';

  @override
  String get tapToConnectPhone => 'Touchez pour vous connecter';

  @override
  String get tapToDisconnectPhone => 'Touchez pour vous déconnecter';

  @override
  String lanAddress(String address) {
    return 'LAN $address';
  }

  @override
  String get recommendedLocation => 'Emplacement recommandé';

  @override
  String dataLeftOf(String limit) {
    return 'sur $limit';
  }

  @override
  String get homeLocation => 'Emplacement';

  @override
  String get connectedTo => 'Connecté à';

  @override
  String get vpnNotAllowed =>
      'Le VPN a besoin de votre autorisation. Touchez à nouveau le bouton et autorisez-le.';

  @override
  String get dataUsedTitle => 'Données utilisées';

  @override
  String get bypassApps => 'Proxy par application';

  @override
  String get connectRetrying =>
      'Connexion impossible. Vérifiez votre internet.';

  @override
  String get failUnreachable =>
      'Les serveurs de Mozilla sont bloqués sur ce réseau. Essayez une autre connexion internet.';

  @override
  String get failRefused =>
      'Le serveur de Mozilla a refusé la connexion. Réessayez dans quelques minutes.';

  @override
  String get failLocationRefused =>
      'Ce pays n\'est pas ouvert à votre compte. Choisissez un autre pays.';

  @override
  String get useRecommendedLocation => 'Utiliser l\'emplacement recommandé';

  @override
  String exitMismatch(String exit, String chosen) {
    return 'Pays choisi : $chosen ; pays de votre IP : $exit.';
  }

  @override
  String get failSignIn =>
      'La connexion de ce compte a expiré. Reconnectez-vous depuis la page Comptes.';

  @override
  String get failQuota =>
      'Les données de ce mois sont épuisées. Ajoutez un autre compte.';

  @override
  String get failNotEntitled =>
      'Mozilla n\'autorise pas ce compte à utiliser le VPN. Ajoutez un autre compte.';

  @override
  String get failRegion =>
      'Mozilla ne propose pas son service dans votre pays.';

  @override
  String get failServer =>
      'Le service de Mozilla a un problème temporaire. L\'application réessaie d\'elle-même.';

  @override
  String get failNoAccount =>
      'Aucun compte n\'est prêt. Ouvrez la page Comptes.';

  @override
  String get failTestSite =>
      'Connecté au serveur, mais les sites ne s\'ouvrent pas. Essayez un autre pays.';

  @override
  String get failOther => 'Connexion impossible. Réessayez.';

  @override
  String get failNoInternet =>
      'Pas d\'internet. Vérifiez le Wi-Fi ou les données mobiles.';

  @override
  String get waitingForNetwork => 'En attente d\'une connexion internet…';

  @override
  String proxyStartFailed(String port) {
    return 'Le proxy n\'a pas pu démarrer sur le port $port. Choisissez un autre port.';
  }

  @override
  String get connectionSettings => 'Paramètres de connexion';

  @override
  String get appModeExclude => 'Exclure les applications choisies';

  @override
  String get appModeInclude => 'VPN uniquement pour les applications choisies';

  @override
  String get appModeExcludeHint =>
      'Les applications choisies se connectent directement, sans le VPN : par exemple les applications bancaires qui refusent les adresses étrangères.';

  @override
  String get appModeIncludeHint =>
      'Seules les applications choisies passent par le VPN ; les autres se connectent directement.';

  @override
  String fromRegionList(String region) {
    return 'Suggérée : liste $region';
  }

  @override
  String get modeProxy => 'Proxy';

  @override
  String get connectionMode => 'Mode de connexion';

  @override
  String get modeProxyHint =>
      'Seules les applications configurées pour utiliser le proxy passent par lui ; Windows reste inchangé.';

  @override
  String get modeSystemProxyHint =>
      'Windows et la plupart des applications passent par le proxy.';

  @override
  String get modeProxyHintOther =>
      'Seules les applications configurées pour utiliser le proxy passent par lui ; les réglages du système restent inchangés.';

  @override
  String get modeSystemProxyHintOther =>
      'Les navigateurs et la plupart des applications passent par le proxy.';

  @override
  String get suggestedApps => 'Applications suggérées';

  @override
  String suggestedAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count applications suggérées sélectionnées',
      one: '1 application suggérée sélectionnée',
      zero: 'Les applications suggérées sont déjà sélectionnées',
    );
    return '$_temp0';
  }

  @override
  String get autoSection => 'Automatique';

  @override
  String get locationsSection => 'Emplacements';

  @override
  String get dnsSummaryOk => 'Le DNS chiffré fonctionne';

  @override
  String dnsSummaryFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count noms n\'ont pas été résolus',
      one: '1 nom n\'a pas été résolu',
    );
    return '$_temp0';
  }

  @override
  String dnsVia(String server) {
    return 'via $server';
  }

  @override
  String dnsSummaryDiffers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Le DNS de votre réseau a renvoyé une adresse de filtrage pour $count noms. L\'application ignore ces réponses.',
      one: 'Le DNS de votre réseau a renvoyé une adresse de filtrage pour 1 nom. L\'application ignore cette réponse.',
    );
    return '$_temp0';
  }

  @override
  String get dnsAnswer => 'Réponse :';

  @override
  String get dnsNetworkAnswer => 'DNS du réseau :';

  @override
  String get dnsFiltered => 'filtré';

  @override
  String get rulesSyntaxTitle => 'Une règle par ligne';

  @override
  String get ruleDomain => 'Le site et ses sous-domaines';

  @override
  String get ruleFull => 'Exactement ce nom';

  @override
  String get ruleKeyword => 'Noms contenant le mot';

  @override
  String get ruleGeosite => 'Sites d\'un tag dans les fichiers Geo';

  @override
  String get ruleGeoip => 'Adresses d\'un pays dans les fichiers Geo';

  @override
  String get ruleIp => 'Une adresse ou un réseau';

  @override
  String get modeVpn => 'VPN';

  @override
  String get modeProxyOnly => 'Proxy uniquement';

  @override
  String get noNetwork =>
      'Pas de connexion Internet. Activez le Wi-Fi ou les données mobiles.';

  @override
  String get blockAds => 'Bloquer les publicités';

  @override
  String systemProxyTakenBy(String address) {
    return 'Un autre programme a réglé le proxy système sur $address ; le trafic ne passe donc plus par le VPN.';
  }

  @override
  String get systemProxyTakenOff =>
      'Un autre programme a désactivé le proxy système ; le trafic ne passe donc plus par le VPN.';

  @override
  String get setSystemProxyAgain => 'Le régler à nouveau';
}
