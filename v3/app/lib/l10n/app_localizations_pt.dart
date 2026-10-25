// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'Firefox VPN';

  @override
  String get navOverview => 'Visão geral';

  @override
  String get navAccounts => 'Contas';

  @override
  String get navSettings => 'Configurações';

  @override
  String get stateConnected => 'Conectado';

  @override
  String get stateConnecting => 'Conectando…';

  @override
  String get stateWaiting => 'Aguardando';

  @override
  String get waitingForAccount =>
      'Adicione uma Firefox Account na página Contas para conectar.';

  @override
  String get waitingForEnabledAccount =>
      'Todas as contas estão desativadas. Ative uma na página Contas.';

  @override
  String get stateError => 'Erro';

  @override
  String get stateUnknown => 'Desconhecido';

  @override
  String get restartProxy => 'Reiniciar o proxy';

  @override
  String copied(String value) {
    return '$value copiado';
  }

  @override
  String get activeAccount => 'Conta ativa';

  @override
  String get noActiveAccount => 'Nenhuma conta ativa';

  @override
  String get quotaNotRead => 'Franquia ainda não verificada';

  @override
  String get unlimited => 'Ilimitado';

  @override
  String usedOf(String used, String limit) {
    return '$used de $limit usados';
  }

  @override
  String resets(String date) {
    return 'zera em $date';
  }

  @override
  String switchAt(int percent) {
    return 'Troca de conta em $percent%';
  }

  @override
  String get publicIp => 'IP público';

  @override
  String get testConnection => 'Testar conexão';

  @override
  String get testing => 'Testando…';

  @override
  String get testFailed => 'Falhou';

  @override
  String milliseconds(int value) {
    return '$value ms';
  }

  @override
  String get justNow => 'agora mesmo';

  @override
  String minutesAgo(int n) {
    return 'há $n min';
  }

  @override
  String hoursAgo(int n) {
    return 'há $n h';
  }

  @override
  String daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'há $count dias',
      one: 'há 1 dia',
    );
    return '$_temp0';
  }

  @override
  String atTime(String time) {
    return 'às $time';
  }

  @override
  String durationDays(int d, int h) {
    return '${d}d ${h}h';
  }

  @override
  String durationHours(int h, int m) {
    return '${h}h ${m}min';
  }

  @override
  String durationMinutes(int m, int s) {
    return '${m}min ${s}s';
  }

  @override
  String durationSeconds(int s) {
    return '${s}s';
  }

  @override
  String accountsGuide(String size) {
    return 'Cada Firefox Account tem $size de franquia por mês. Você pode adicionar várias: quando uma acaba, o app passa sozinho para a próxima.';
  }

  @override
  String accountsOrderNote(int percent) {
    return 'Na ordem desta lista: cada uma até $percent%, a última até acabarem os dados.';
  }

  @override
  String get addAccount => 'Adicionar conta';

  @override
  String lowQuotaNotice(String left, String size) {
    return 'A franquia da conta atual está acabando (restam $left). Adicione outra conta para ter mais $size.';
  }

  @override
  String get noAccounts => 'Nenhuma conta ainda';

  @override
  String get noAccountsHint => 'Adicione uma Firefox Account para conectar.';

  @override
  String get createAccountTitle => 'Não tem uma Firefox Account?';

  @override
  String get createAccountHint =>
      'Crie uma grátis em accounts.firefox.com, depois volte e toque em Adicionar conta.';

  @override
  String get moveUp => 'Mover para cima';

  @override
  String get moveDown => 'Mover para baixo';

  @override
  String get statusActive => 'Ativa';

  @override
  String get statusReady => 'Pronta';

  @override
  String get statusNeedsSignIn => 'Requer login';

  @override
  String get statusReserved => 'Reservada';

  @override
  String get statusUnavailable => 'Indisponível';

  @override
  String statusUnavailableUntil(String date) {
    return 'Indisponível até $date';
  }

  @override
  String get statusDisabled => 'Desativada';

  @override
  String get statusEnabled => 'Ativada';

  @override
  String get useNow => 'Usar agora';

  @override
  String get signInAgain => 'Entrar novamente';

  @override
  String reasonQuotaThreshold(int percent) {
    return 'Esta conta usou $percent% dos dados, então a próxima assumiu.';
  }

  @override
  String get reasonQuotaExhausted =>
      'A franquia deste mês acabou; volta a ser usada após a renovação mensal.';

  @override
  String get reasonSignInRequired => 'Entre de novo para usar esta conta.';

  @override
  String get reasonSignInConfirm =>
      'A Mozilla pede para confirmar o login: toque em «Entrar novamente» (só o código é necessário).';

  @override
  String reasonSignInFailed(String detail) {
    return 'O login automático falhou ($detail). Entre de novo.';
  }

  @override
  String reasonSignInWait(String time) {
    return 'O último login automático parou de funcionar logo depois; a próxima tentativa é às $time.';
  }

  @override
  String reasonSignInRetry(String detail, String time) {
    return 'O login automático não terminou ($detail); nova tentativa às $time.';
  }

  @override
  String get reasonNotEntitled =>
      'A Mozilla recusou esta conta; nova tentativa mais tarde.';

  @override
  String get more => 'Mais';

  @override
  String get refreshQuota => 'Atualizar franquia';

  @override
  String get remove => 'Remover';

  @override
  String get removeTitle => 'Remover conta?';

  @override
  String removeBody(String name) {
    return '$name e o login salvo serão removidos deste computador. Você pode adicioná-la novamente depois.';
  }

  @override
  String get unlimitedQuota => 'Franquia ilimitada';

  @override
  String get signInTitle => 'Entrar';

  @override
  String get signInIntro => 'Entre com uma Firefox Account.';

  @override
  String get email => 'E-mail';

  @override
  String get emailInvalid => 'Digite o e-mail da conta';

  @override
  String get password => 'Senha';

  @override
  String get passwordEmpty => 'Digite a senha';

  @override
  String get show => 'Mostrar';

  @override
  String get hide => 'Ocultar';

  @override
  String get signIn => 'Entrar';

  @override
  String get continueLabel => 'Continuar';

  @override
  String get done => 'Concluído';

  @override
  String get close => 'Fechar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get tryAgain => 'Tentar novamente';

  @override
  String get signingIn => 'Entrando…';

  @override
  String get accountReady => 'Conta pronta';

  @override
  String get accountReadyHint => 'Ela foi adicionada ao final da lista.';

  @override
  String get captchaLabel => 'Caracteres da imagem';

  @override
  String get codeLabel => 'Código';

  @override
  String get captchaBroken => 'Não foi possível mostrar a imagem do CAPTCHA.';

  @override
  String stepEmailCode(String email) {
    return 'A Mozilla enviou um código para $email. Digite-o aqui.';
  }

  @override
  String get stepTotp => 'Digite o código do seu app autenticador.';

  @override
  String stepUnblockCode(String email) {
    return 'A Mozilla considerou este login incomum e enviou um código de desbloqueio para $email. Digite-o aqui.';
  }

  @override
  String get stepCaptcha => 'Digite os caracteres da imagem.';

  @override
  String stepEmailLink(String email) {
    return 'Abra o link de confirmação que a Mozilla enviou para $email. O app continua automaticamente.';
  }

  @override
  String get signInFailed => 'A conta não foi adicionada.';

  @override
  String get signInCancelled => 'Entrada cancelada.';

  @override
  String get signInNoAccount => 'Não existe Firefox Account com este e-mail.';

  @override
  String get signInNoAccountHint =>
      'Confira o e-mail, ou crie com ele uma Firefox Account gratuita no site da Mozilla, confirme-a pela sua caixa de entrada e depois adicione-a aqui.';

  @override
  String get createAccountButton => 'Criar uma Firefox Account';

  @override
  String get signInWrongPassword => 'Senha incorreta.';

  @override
  String get signInNoPassword =>
      'Esta conta não tem senha: foi criada com o login do Google ou da Apple. Defina uma senha e depois entre aqui com ela.';

  @override
  String get setPasswordButton => 'Definir senha';

  @override
  String get signInTooManyAttempts =>
      'Tentativas demais. Aguarde um pouco e tente de novo.';

  @override
  String get signInUnblockRejected =>
      'O código de desbloqueio não foi aceito. Use o código do e-mail mais recente da Mozilla.';

  @override
  String get signInWrongCode =>
      'Código errado ou expirado. Use o código do e-mail mais recente da Mozilla; um código antigo para de funcionar quando um novo é enviado.';

  @override
  String get signInWrongTotp =>
      'Código errado. Digite o código que o app autenticador mostra agora.';

  @override
  String get signInTooManyCodes =>
      'Códigos errados demais. Comece a entrada de novo.';

  @override
  String get signInTimedOut => 'A entrada demorou demais. Comece de novo.';

  @override
  String get signInNetwork =>
      'Não foi possível alcançar a Mozilla. Verifique sua internet e tente de novo.';

  @override
  String get coreConnecting => 'Conectando ao núcleo…';

  @override
  String get coreLost =>
      'A conexão com o núcleo foi perdida. Tentando novamente…';

  @override
  String get cantReachCore => 'Não foi possível conectar ao núcleo';

  @override
  String get startingCore => 'Iniciando o núcleo…';

  @override
  String get retry => 'Tentar de novo';

  @override
  String errNoCore(String path) {
    return 'O núcleo não foi encontrado na pasta do app ($path).';
  }

  @override
  String errCoreExited(String detail) {
    return 'O núcleo parou: $detail';
  }

  @override
  String get errNotAnswering => 'O núcleo não está respondendo.';

  @override
  String get errRefused =>
      'O núcleo recusou a conexão; talvez ele pertença a outra cópia do app.';

  @override
  String get settingsTitle => 'Configurações';

  @override
  String get sectionGeneral => 'Geral';

  @override
  String get language => 'Idioma';

  @override
  String get languageSystem => 'Padrão do sistema';

  @override
  String get theme => 'Tema';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Escuro';

  @override
  String get closeBehavior => 'Ao fechar a janela';

  @override
  String get closeAsk => 'Perguntar sempre';

  @override
  String get closeTray => 'Minimizar para a bandeja';

  @override
  String get closeQuit => 'Sair do app';

  @override
  String get sectionConnection => 'Conexão';

  @override
  String get localProxy => 'Proxy local';

  @override
  String get systemProxy => 'Proxy do sistema';

  @override
  String get sectionRouting => 'Roteamento';

  @override
  String get routingDirect => 'Conexão direta para sites locais';

  @override
  String get routingDirectHint =>
      'Sites e IPs do país escolhido não passam pela VPN: abrem mais rápido e não gastam a franquia.';

  @override
  String get region => 'País';

  @override
  String get regionIr => 'Irã';

  @override
  String get regionCn => 'China';

  @override
  String get regionRu => 'Rússia';

  @override
  String get regionAf => 'Afeganistão';

  @override
  String get regionTr => 'Turquia';

  @override
  String get regionId => 'Indonésia';

  @override
  String get regionBr => 'Brasil';

  @override
  String get regionNone => 'Nenhum';

  @override
  String get saved => 'Salvo';

  @override
  String get dataFolder => 'Pasta de dados';

  @override
  String get openFolder => 'Abrir pasta';

  @override
  String get unofficialNote =>
      'Cliente não oficial. Sem vínculo com a Mozilla.';

  @override
  String get closeTitle => 'Fechar a janela?';

  @override
  String get closeBody =>
      'Minimizada na bandeja, a VPN continua conectada. Ao sair, ela é desligada.';

  @override
  String get rememberChoice => 'Lembrar minha escolha';

  @override
  String get minimizeToTray => 'Minimizar para a bandeja';

  @override
  String get quit => 'Sair';

  @override
  String get trayOpen => 'Abrir';

  @override
  String get trayQuit => 'Sair';

  @override
  String get trayProxyOnly => 'Somente serviço de proxy';

  @override
  String get traySetSystemProxy => 'Definir proxy do sistema';

  @override
  String errPortInUse(String port) {
    return 'A porta $port está sendo usada por outro programa, por isso o app não consegue se conectar ao núcleo.';
  }

  @override
  String proxyPortInUse(String port) {
    return 'A porta $port está sendo usada por outro programa, por isso o proxy não consegue iniciar.';
  }

  @override
  String get changePort => 'Trocar porta';

  @override
  String get portDialogTitle => 'Escolha uma porta';

  @override
  String portDialogBody(String port) {
    return 'A porta $port está ocupada. Uma porta livre é sugerida abaixo; você pode digitar outra.';
  }

  @override
  String get portChangeBody =>
      'Os apps se conectam a esta porta. Escolha uma entre 1024 e 65535.';

  @override
  String get portLabel => 'Porta';

  @override
  String get portInvalid => 'Digite uma porta de 1024 a 65535';

  @override
  String get portBusy => 'Esta porta também está em uso';

  @override
  String get portInUse => 'Outro programa usa esta porta';

  @override
  String get save => 'Salvar';

  @override
  String get proxyPort => 'Porta do proxy';

  @override
  String get appPort => 'Porta do app';

  @override
  String get welcomeTitle => 'Boas-vindas';

  @override
  String get welcomeBody =>
      'Escolha seu idioma e seu país. Os sites do seu país abrem diretamente, sem a VPN: mais rápido e sem gastar a franquia.';

  @override
  String get start => 'Começar';

  @override
  String routingSuggestTitle(String country) {
    return '$country: abrir sites diretamente?';
  }

  @override
  String routingSuggestBody(String country) {
    return 'Sites e IPs do país escolhido ($country) abririam diretamente, sem a VPN. Você pode mudar isso em Roteamento.';
  }

  @override
  String get yes => 'Sim';

  @override
  String get notNow => 'Agora não';

  @override
  String get navServers => 'Servidores';

  @override
  String get navLogs => 'Logs';

  @override
  String get realDelay => 'Latência real';

  @override
  String noticePort(String port) {
    return 'O proxy da Mozilla não se conecta à porta $port. Apenas as portas 80, 443, 8080 e 8443 passam pela VPN.';
  }

  @override
  String get noticeCommand =>
      'Um app tentou usar UDP (jogos, chamadas de voz e vídeo). O proxy da Mozilla só aceita TCP, então essa conexão não pode passar.';

  @override
  String noticeTimes(int count, String time) {
    return '$count vezes, última às $time';
  }

  @override
  String get dismiss => 'Dispensar';

  @override
  String get modeRecommended => 'Recomendado';

  @override
  String get modeFastest => 'Mais rápido';

  @override
  String get modeRecommendedHint => 'A Mozilla escolhe o local para você.';

  @override
  String get modeFastestHint => 'O local com menor latência a cada conexão.';

  @override
  String get testDelay => 'Testar latência real';

  @override
  String get testingDelay => 'Testando… isso pode levar um minuto';

  @override
  String get search => 'Pesquisar';

  @override
  String get noAnswer => 'Sem resposta';

  @override
  String testedAgo(String ago) {
    return 'Testado $ago';
  }

  @override
  String delaySummary(int answered, int total) {
    return '$answered de $total responderam';
  }

  @override
  String get noServers =>
      'Nenhum servidor ainda. Eles aparecem assim que o núcleo se conectar à Mozilla.';

  @override
  String get levelAll => 'Todos';

  @override
  String get filter => 'Filtrar';

  @override
  String get follow => 'Rolagem automática';

  @override
  String get clear => 'Limpar';

  @override
  String get copyAll => 'Copiar';

  @override
  String get logsCopied => 'Logs copiados';

  @override
  String get noLogs => 'Nenhuma linha de log ainda.';

  @override
  String get sectionAccounts => 'Troca automática de conta';

  @override
  String get switchThreshold => 'Trocar de conta em';

  @override
  String get switchThresholdHint =>
      'A próxima conta assume quando esta porcentagem da franquia for consumida.';

  @override
  String get sectionDns => 'DNS';

  @override
  String get dnsPreset => 'Servidores DNS';

  @override
  String get dnsSystem => 'Sistema';

  @override
  String get dnsAuto => 'Automático (Cloudflare, Google, Quad9)';

  @override
  String get dnsCustom => 'Personalizado';

  @override
  String get dnsCustomHint =>
      'Um por linha: https://…/dns-query, tls://… ou um endereço IP.';

  @override
  String get dnsFallback => 'Usar o DNS do sistema como alternativa';

  @override
  String get testDns => 'Testar DNS';

  @override
  String get transport => 'Protocolo';

  @override
  String get transportH3 => 'HTTP/3 (QUIC)';

  @override
  String get transportH2 => 'HTTP/2 (TCP)';

  @override
  String get directRules => 'Direto';

  @override
  String get directRulesHint =>
      'Os sites e endereços desta lista abrem sem a VPN, direto pela sua própria internet. As regras do país escolhido já estão aqui: adicione, altere ou remova linhas. Escolher outro país as substitui pelas dele.';

  @override
  String get restoreRegionRules => 'Restaurar as regras do país';

  @override
  String get blockRules => 'Bloquear';

  @override
  String get blockRulesHint =>
      'Os sites e endereços desta lista não abrem de jeito nenhum, nem direto nem pela VPN: para anúncios ou sites que você nunca quer acessar.';

  @override
  String get rulesTitle => 'Regras';

  @override
  String get ruleSyntaxTitle => 'Como escrever uma regra';

  @override
  String get resolveDomains => 'Aplicar regras de IP aos domínios';

  @override
  String get routingLists => 'Arquivos geo';

  @override
  String get listSource => 'Origem das listas';

  @override
  String get listSourceCustom => 'Definido manualmente';

  @override
  String listsUpdatedAgo(String ago) {
    return 'Atualizado $ago';
  }

  @override
  String get updateLists => 'Atualizar os arquivos geo';

  @override
  String get listsUpdated => 'Os arquivos geo foram atualizados.';

  @override
  String get testDestination => 'Testar a rota de um site';

  @override
  String get destinationHint => 'Um nome, um endereço ou uma URL';

  @override
  String get check => 'Verificar';

  @override
  String get routeDirect => 'Vai direto';

  @override
  String get routeProxy => 'Passa pela VPN';

  @override
  String get routeBlock => 'Bloqueado';

  @override
  String ruleMatched(String rule) {
    return 'Regra: $rule';
  }

  @override
  String get portRefusedNote =>
      'O proxy da Mozilla não se conecta a esta porta.';

  @override
  String get sectionAdvanced => 'Avançado';

  @override
  String get listenAddress => 'Acesso ao proxy';

  @override
  String get listenLocal => '127.0.0.1 · somente este dispositivo';

  @override
  String get listenAll => '0.0.0.0 · todas as redes (LAN)';

  @override
  String get proxyUsername => 'Usuário do proxy';

  @override
  String get proxyPassword => 'Senha do proxy';

  @override
  String get proxyLoginHint =>
      'Os apps terão que usar este usuário e senha. Deixe os dois em branco para não exigir senha.';

  @override
  String get loginBothOrNone => 'Preencha os dois ou deixe os dois vazios.';

  @override
  String get proxyLogin => 'Usuário e senha do proxy';

  @override
  String get idleSleep => 'Pausar após inatividade de';

  @override
  String get sleepNever => 'Nunca';

  @override
  String sleepMinutes(int count) {
    return '$count minutos';
  }

  @override
  String get sleepHour => '1 hora';

  @override
  String get showPublicIp => 'Mostrar o IP público';

  @override
  String get speedInNotification => 'Mostrar a velocidade na notificação';

  @override
  String get liveTraffic => 'Tráfego ao vivo';

  @override
  String get totalTraffic => 'Tráfego total';

  @override
  String get verboseLogs => 'Logs detalhados';

  @override
  String get webDashboard => 'Painel web';

  @override
  String get webDashboardOpen => 'Abrir';

  @override
  String get webDashboardHint => 'Configurações avançadas e mais ferramentas';

  @override
  String numberInvalid(int min, int max) {
    return 'Digite um número de $min a $max';
  }

  @override
  String get notifySwitchedTitle => 'Conta trocada';

  @override
  String notifySwitchedBody(String name) {
    return 'Usando agora $name.';
  }

  @override
  String get notifySignInTitle => 'Login necessário';

  @override
  String get notifySignInBody =>
      'Uma conta precisa fazer login novamente. Abra a página Contas.';

  @override
  String get navAbout => 'Sobre';

  @override
  String get appVersionLabel => 'Versão do app';

  @override
  String get coreVersionLabel => 'Versão do núcleo';

  @override
  String get checkUpdates => 'Verificar atualizações';

  @override
  String get checkingUpdates => 'Verificando…';

  @override
  String get upToDate => 'Você tem a versão mais recente.';

  @override
  String updateAvailable(String version) {
    return 'A versão $version está disponível.';
  }

  @override
  String get download => 'Baixar';

  @override
  String updateCheckFailed(String error) {
    return 'Não foi possível verificar atualizações: $error';
  }

  @override
  String get repoNotSet => 'O repositório do GitHub ainda não foi definido.';

  @override
  String get sourceCode => 'Código-fonte';

  @override
  String get tapToConnect => 'Clique para conectar';

  @override
  String get tapToDisconnect => 'Clique para desconectar';

  @override
  String get startOnBoot => 'Iniciar com o sistema';

  @override
  String get connectOnStartup => 'Conectar ao iniciar o sistema';

  @override
  String get proxyServiceActive => 'Serviço de proxy ativo';

  @override
  String get navHome => 'Início';

  @override
  String get groupApp => 'App';

  @override
  String get stateOff => 'Desconectado';

  @override
  String get tapToConnectPhone => 'Toque para conectar';

  @override
  String get tapToDisconnectPhone => 'Toque para desconectar';

  @override
  String lanAddress(String address) {
    return 'LAN $address';
  }

  @override
  String get recommendedLocation => 'Local recomendado';

  @override
  String dataLeftOf(String limit) {
    return 'de $limit';
  }

  @override
  String get homeLocation => 'Local';

  @override
  String get connectedTo => 'Conectado a';

  @override
  String get vpnNotAllowed =>
      'A VPN precisa da sua permissão. Toque no botão de novo e permita.';

  @override
  String get dataUsedTitle => 'Dados usados';

  @override
  String get bypassApps => 'Proxy por app';

  @override
  String get connectRetrying =>
      'Não foi possível conectar. Verifique sua internet.';

  @override
  String get failUnreachable =>
      'Os servidores da Mozilla estão bloqueados nesta internet. Tente outra conexão.';

  @override
  String get failRefused =>
      'O servidor da Mozilla recusou a conexão. Tente de novo em alguns minutos.';

  @override
  String get failLocationRefused =>
      'Este país não está disponível para sua conta. Escolha outro país.';

  @override
  String get useRecommendedLocation => 'Usar o local recomendado';

  @override
  String exitMismatch(String exit, String chosen) {
    return 'País escolhido: $chosen. País do seu IP: $exit.';
  }

  @override
  String get failSignIn =>
      'O login desta conta expirou. Entre novamente na página Contas.';

  @override
  String get failQuota => 'Os dados deste mês acabaram. Adicione outra conta.';

  @override
  String get failNotEntitled =>
      'A Mozilla não permite que esta conta use a VPN. Adicione outra conta.';

  @override
  String get failRegion => 'A Mozilla não oferece o serviço no seu país.';

  @override
  String get failServer =>
      'O serviço da Mozilla está com um problema temporário. O app tentará de novo sozinho.';

  @override
  String get failNoAccount =>
      'Nenhuma conta está pronta. Abra a página Contas.';

  @override
  String get failTestSite =>
      'Conectado ao servidor, mas os sites não abrem. Tente outro país.';

  @override
  String get failOther => 'Não foi possível conectar. Tente de novo.';

  @override
  String get failNoInternet =>
      'Sem internet. Verifique o Wi-Fi ou os dados móveis.';

  @override
  String get waitingForNetwork => 'Aguardando conexão com a internet…';

  @override
  String proxyStartFailed(String port) {
    return 'O proxy não conseguiu iniciar na porta $port. Escolha outra porta.';
  }

  @override
  String get connectionSettings => 'Configurações de conexão';

  @override
  String get appModeExclude => 'Excluir apps selecionados';

  @override
  String get appModeInclude => 'Somente apps selecionados';

  @override
  String get appModeExcludeHint =>
      'Os apps selecionados se conectam diretamente, sem a VPN: por exemplo, apps de banco que recusam endereços estrangeiros.';

  @override
  String get appModeIncludeHint =>
      'Apenas os apps selecionados passam pela VPN; os outros se conectam diretamente.';

  @override
  String fromRegionList(String region) {
    return 'Sugerido pela lista: $region';
  }

  @override
  String get modeProxy => 'Proxy';

  @override
  String get connectionMode => 'Modo de conexão';

  @override
  String get modeProxyHint =>
      'Apenas os apps configurados para usar o proxy passam por ele; o Windows fica como está.';

  @override
  String get modeSystemProxyHint =>
      'O Windows e a maioria dos apps passam pelo proxy.';

  @override
  String get modeProxyHintOther =>
      'Apenas os apps configurados para usar o proxy passam por ele; as configurações do sistema ficam como estão.';

  @override
  String get modeSystemProxyHintOther =>
      'Os navegadores e a maioria dos apps passam pelo proxy.';

  @override
  String get suggestedApps => 'Apps sugeridos';

  @override
  String suggestedAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count apps sugeridos selecionados',
      one: '1 app sugerido selecionado',
      zero: 'Os apps sugeridos já estão selecionados',
    );
    return '$_temp0';
  }

  @override
  String get autoSection => 'Automático';

  @override
  String get locationsSection => 'Locais';

  @override
  String get dnsSummaryOk => 'O DNS criptografado está funcionando';

  @override
  String dnsSummaryFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nomes não foram resolvidos',
      one: '1 nome não foi resolvido',
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
          'O DNS da sua rede respondeu $count nomes com um endereço de bloqueio. Este app não usa esse DNS para eles.',
      one: 'O DNS da sua rede respondeu 1 nome com um endereço de bloqueio. Este app não usa esse DNS para ele.',
    );
    return '$_temp0';
  }

  @override
  String get dnsAnswer => 'Resposta:';

  @override
  String get dnsNetworkAnswer => 'DNS da rede:';

  @override
  String get dnsFiltered => 'filtrado';

  @override
  String get rulesSyntaxTitle => 'Uma regra por linha';

  @override
  String get ruleDomain => 'O site e seus subdomínios';

  @override
  String get ruleFull => 'Exatamente este nome';

  @override
  String get ruleKeyword => 'Nomes que contêm a palavra';

  @override
  String get ruleGeosite => 'Sites de uma tag nos arquivos geo';

  @override
  String get ruleGeoip => 'Endereços de um país nos arquivos geo';

  @override
  String get ruleIp => 'Um endereço ou uma rede';

  @override
  String get modeVpn => 'VPN';

  @override
  String get modeProxyOnly => 'Somente proxy';

  @override
  String get noNetwork =>
      'Sem conexão com a internet. Ative o Wi-Fi ou os dados móveis.';

  @override
  String get blockAds => 'Bloquear anúncios';

  @override
  String systemProxyTakenBy(String address) {
    return 'Outro programa mudou o proxy do sistema para $address, então o tráfego não passa pela VPN.';
  }

  @override
  String get systemProxyTakenOff =>
      'Outro programa desativou o proxy do sistema, então o tráfego não passa pela VPN.';

  @override
  String get setSystemProxyAgain => 'Configurar de novo';
}
