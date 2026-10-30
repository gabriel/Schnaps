import Foundation

/// Small app-owned catalog; language changes apply without changing macOS preferences.
func L(_ key: String) -> String {
    let chosen = UserDefaults.standard.string(forKey: PreferenceKey.language) ?? "system"
    let language = chosen == "system" ? Locale.preferredLanguages.first ?? "en" : chosen
    let code = language.hasPrefix("zh") ? "zh-Hans" : String(language.prefix(2))
    guard let index = ["zh-Hans", "es", "fr", "it", "ja", "ru"].firstIndex(of: code),
        let values = SchnapsTranslations.values[key], values.indices.contains(index)
    else { return key }
    return values[index]
}
private enum SchnapsTranslations {
    static let values: [String: [String]] = {
        var result = [String: [String]]()
        for line in catalog.split(separator: "\n") {
            let parts = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            if parts.count == 7 { result[parts[0]] = Array(parts.dropFirst()) }
        }
        return result
    }()
    static let catalog = """
        General|通用|General|Général|Generali|一般|Основные
        Screenshots|截图|Capturas|Captures d’écran|Screenshot|スクリーンショット|Снимки экрана
        Tolerance|容差|Tolerancia|Tolérance|Tolleranza|許容値|Допуск
        Appearance|外观|Apariencia|Apparence|Aspetto|外観|Оформление
        Shortcuts|快捷键|Atajos|Raccourcis|Scorciatoie|ショートカット|Сочетания клавиш
        Permissions|权限|Permisos|Autorisations|Permessi|アクセス権|Разрешения
        About Schnaps|关于 Schnaps|Acerca de Schnaps|À propos de Schnaps|Informazioni su Schnaps|Schnaps について|О Schnaps
        Tools|工具|Herramientas|Outils|Strumenti|ツール|Инструменты
        Find Dimensions|查找尺寸|Buscar dimensiones|Trouver les dimensions|Trova dimensioni|寸法を検出|Найти размеры
        Measure Area|测量区域|Medir área|Mesurer une zone|Misura area|領域を測定|Измерить область
        Language|语言|Idioma|Langue|Lingua|言語|Язык
        System Default|系统默认|Predeterminado del sistema|Valeur du système|Predefinito di sistema|システム設定|Как в системе
        Activation|启动|Activación|Activation|Attivazione|起動|Запуск
        Default tool|默认工具|Herramienta predeterminada|Outil par défaut|Strumento predefinito|既定のツール|Инструмент по умолчанию
        Start at login|登录时启动|Abrir al iniciar sesión|Ouvrir à la connexion|Apri al login|ログイン時に起動|Запускать при входе
        Show in menu bar|在菜单栏中显示|Mostrar en barra de menús|Afficher dans la barre des menus|Mostra nella barra dei menu|メニューバーに表示|Показывать в строке меню
        Show in Dock|在程序坞中显示|Mostrar en el Dock|Afficher dans le Dock|Mostra nel Dock|Dock に表示|Показывать в Dock
        Measurement|测量|Medición|Mesure|Misurazione|測定|Измерение
        Retina measurements|Retina 测量|Medidas Retina|Mesures Retina|Misure Retina|Retina の測定|Измерения Retina
        Points|点|Puntos|Points|Punti|ポイント|Пункты
        Points (rounded)|点（取整）|Puntos (redondeados)|Points (arrondis)|Punti (arrotondati)|ポイント（整数）|Пункты (округлённые)
        Display pixels|屏幕像素|Píxeles de pantalla|Pixels de l’écran|Pixel dello schermo|画面のピクセル|Пиксели экрана
        Clipboard format|剪贴板格式|Formato del portapapeles|Format du presse-papiers|Formato appunti|クリップボード形式|Формат буфера обмена
        Width, height|宽度，高度|Ancho, alto|Largeur, hauteur|Larghezza, altezza|幅、高さ|Ширина, высота
        Height, width|高度，宽度|Alto, ancho|Hauteur, largeur|Altezza, larghezza|高さ、幅|Высота, ширина
        CSS (width first)|CSS（宽度优先）|CSS (ancho primero)|CSS (largeur d’abord)|CSS (prima larghezza)|CSS（幅を先に）|CSS (сначала ширина)
        CSS (height first)|CSS（高度优先）|CSS (alto primero)|CSS (hauteur d’abord)|CSS (prima altezza)|CSS（高さを先に）|CSS (сначала высота)
        SASS (width first)|SASS（宽度优先）|SASS (ancho primero)|SASS (largeur d’abord)|SASS (prima larghezza)|SASS（幅を先に）|SASS (сначала ширина)
        SASS (height first)|SASS（高度优先）|SASS (alto primero)|SASS (hauteur d’abord)|SASS (prima altezza)|SASS（高さを先に）|SASS (сначала высота)
        Display units|显示单位|Mostrar unidades|Afficher les unités|Mostra unità|単位を表示|Показывать единицы
        Display width/height indicators|显示宽高标识|Mostrar indicadores de ancho/alto|Afficher les indicateurs largeur/hauteur|Mostra indicatori larghezza/altezza|幅・高さの印を表示|Показывать обозначения ширины и высоты
        Show cursor|显示光标|Mostrar cursor|Afficher le curseur|Mostra cursore|カーソルを表示|Показывать курсор
        Aspect ratio|宽高比|Relación de aspecto|Rapport d’aspect|Proporzioni|アスペクト比|Соотношение сторон
        Automatic|自动|Automático|Automatique|Automatico|自動|Автоматически
        Standard (16:9)|标准（16:9）|Estándar (16:9)|Standard (16:9)|Standard (16:9)|標準（16:9）|Обычное (16:9)
        Reduced (1.78:1)|小数（1.78:1）|Reducido (1.78:1)|Réduit (1,78:1)|Ridotto (1,78:1)|小数（1.78:1）|Десятичное (1,78:1)
        Only common values|仅常用值|Solo valores comunes|Valeurs courantes uniquement|Solo valori comuni|一般的な比率のみ|Только распространённые
        Show in Find Dimensions|在查找尺寸中显示|Mostrar en Buscar dimensiones|Afficher dans Trouver les dimensions|Mostra in Trova dimensioni|寸法検出で表示|Показывать при поиске размеров
        Show in Measure Area|在测量区域中显示|Mostrar en Medir área|Afficher dans Mesurer une zone|Mostra in Misura area|領域測定で表示|Показывать при измерении области
        Distance tool|距离工具|Herramienta de distancia|Outil de distance|Strumento distanza|距離ツール|Инструмент расстояния
        Snap to guides|吸附到参考线|Ajustar a guías|Aligner sur les guides|Aggancia alle guide|ガイドにスナップ|Привязывать к направляющим
        Snap to selected objects|吸附到已选对象|Ajustar a objetos seleccionados|Aligner sur les objets sélectionnés|Aggancia agli oggetti selezionati|選択したオブジェクトにスナップ|Привязывать к выбранным объектам
        Freeze screen|冻结屏幕|Congelar pantalla|Figer l’écran|Blocca schermo|画面を固定|Заморозить экран
        Keep a still screen while measuring.|测量时使用静态屏幕。|Mantén la pantalla fija al medir.|Garder une image fixe pendant la mesure.|Mantieni lo schermo fermo durante la misura.|測定中は静止画面を使います。|Использовать неподвижный снимок при измерении.
        Export|导出|Exportar|Exporter|Esporta|書き出し|Экспорт
        Export folder|导出文件夹|Carpeta de exportación|Dossier d’exportation|Cartella di esportazione|保存先フォルダ|Папка экспорта
        Choose…|选择…|Elegir…|Choisir…|Scegli…|選択…|Выбрать…
        File format|文件格式|Formato de archivo|Format de fichier|Formato file|ファイル形式|Формат файла
        Scale Retina screenshots to 1x|将 Retina 截图缩放到 1x|Reducir capturas Retina a 1x|Réduire les captures Retina à 1x|Riduci screenshot Retina a 1x|Retina 画像を 1 倍で保存|Уменьшать снимки Retina до 1x
        Play sounds|播放声音|Reproducir sonidos|Jouer des sons|Riproduci suoni|サウンドを再生|Воспроизводить звуки
        Padding|留白|Margen|Marge|Margine|余白|Отступ
        Auto|自动|Auto|Auto|Auto|自動|Авто
        Hold Option to toggle padding when capturing.|截图时按住 Option 切换留白。|Mantén Opción para alternar el margen al capturar.|Maintenir Option pour changer la marge lors de la capture.|Tieni premuto Opzione per cambiare il margine durante la cattura.|撮影時に Option を押して余白を切り替えます。|Удерживайте Option при захвате, чтобы переключить отступ.
        Zero|零|Cero|Zéro|Zero|ゼロ|Нулевой
        Low|低|Baja|Faible|Bassa|低|Низкий
        Medium|中|Media|Moyenne|Media|中|Средний
        High|高|Alta|Élevée|Alta|高|Высокий
        Default tolerance|默认容差|Tolerancia predeterminada|Tolérance par défaut|Tolleranza predefinita|既定の許容値|Допуск по умолчанию
        Scroll to adjust tolerance|滚动调整容差|Desplazar para ajustar tolerancia|Défiler pour régler la tolérance|Scorri per regolare tolleranza|スクロールで許容値を調整|Настраивать допуск прокруткой
        Higher tolerance ignores subtle color differences and shadows.|较高容差忽略细微色差和阴影。|Una tolerancia mayor ignora variaciones sutiles y sombras.|Une tolérance élevée ignore les nuances et les ombres.|Una tolleranza maggiore ignora sfumature e ombre.|許容値を上げると微妙な色や影を無視します。|Высокий допуск игнорирует слабые различия цвета и тени.
        Restore Defaults|恢复默认值|Restaurar valores|Rétablir les valeurs|Ripristina predefiniti|既定値に戻す|Восстановить по умолчанию
        Interface|界面|Interfaz|Interface|Interfaccia|インターフェース|Интерфейс
        System Appearance|系统外观|Apariencia del sistema|Apparence du système|Aspetto di sistema|システムの外観|Как в системе
        Light|浅色|Clara|Clair|Chiaro|ライト|Светлая
        Dark|深色|Oscura|Sombre|Scuro|ダーク|Тёмная
        Animations|动画|Animaciones|Animations|Animazioni|アニメーション|Анимация
        Measurement colors|测量颜色|Colores de medición|Couleurs de mesure|Colori misurazione|測定の色|Цвета измерений
        Overlay color|浮层颜色|Color de superposición|Couleur de superposition|Colore sovrapposizione|オーバーレイの色|Цвет наложения
        Alternative color|备用颜色|Color alternativo|Couleur alternative|Colore alternativo|代替色|Альтернативный цвет
        Auto contrast|自动对比|Contraste automático|Contraste automatique|Contrasto automatico|自動コントラスト|Автоконтраст
        Guides color|参考线颜色|Color de guías|Couleur des guides|Colore guide|ガイドの色|Цвет направляющих
        Press X while measuring to switch colors.|测量时按 X 切换颜色。|Pulsa X al medir para cambiar de color.|Appuyer sur X pendant la mesure pour changer de couleur.|Premi X durante la misura per cambiare colore.|測定中に X を押して色を切り替えます。|Нажмите X при измерении, чтобы сменить цвет.
        Global|全局|Global|Globaux|Globali|グローバル|Глобальные
        While Measuring|测量时|Al medir|Pendant la mesure|Durante la misura|測定中|При измерении
        Copy dimensions|复制尺寸|Copiar dimensiones|Copier les dimensions|Copia dimensioni|寸法をコピー|Копировать размеры
        Copy CSS|复制 CSS|Copiar CSS|Copier le CSS|Copia CSS|CSS をコピー|Копировать CSS
        Pin measurement|固定测量|Fijar medición|Épingler la mesure|Fissa misura|測定を固定|Закрепить измерение
        Copy screenshot|复制截图|Copiar captura|Copier la capture|Copia screenshot|画像をコピー|Копировать снимок
        Save screenshot|保存截图|Guardar captura|Enregistrer la capture|Salva screenshot|画像を保存|Сохранить снимок
        Switch colors|切换颜色|Cambiar colores|Changer les couleurs|Cambia colori|色を切り替え|Сменить цвета
        Close overlay|关闭浮层|Cerrar superposición|Fermer la superposition|Chiudi sovrapposizione|オーバーレイを閉じる|Закрыть наложение
        Screen Recording|屏幕录制|Grabación de pantalla|Enregistrement de l’écran|Registrazione schermo|画面収録|Запись экрана
        Access|访问|Acceso|Accès|Accesso|アクセス|Доступ
        Allowed|已允许|Permitido|Autorisé|Consentito|許可済み|Разрешён
        Not allowed|未允许|No permitido|Non autorisé|Non consentito|未許可|Не разрешён
        Settings…|设置…|Ajustes…|Réglages…|Impostazioni…|設定…|Настройки…
        Start Measuring|开始测量|Empezar a medir|Commencer la mesure|Inizia a misurare|測定を開始|Начать измерение
        Quit Schnaps|退出 Schnaps|Salir de Schnaps|Quitter Schnaps|Esci da Schnaps|Schnaps を終了|Завершить Schnaps
        Check for Updates…|检查更新…|Buscar actualizaciones…|Rechercher des mises à jour…|Cerca aggiornamenti…|アップデートを確認…|Проверить обновления…
        Cancel|取消|Cancelar|Annuler|Annulla|キャンセル|Отмена
        Done|完成|Listo|Terminé|Fine|完了|Готово
        Settings|设置|Ajustes|Réglages|Impostazioni|設定|Настройки
        Schnaps Settings|Schnaps 设置|Ajustes de Schnaps|Réglages Schnaps|Impostazioni Schnaps|Schnaps 設定|Настройки Schnaps
        Color tolerance|颜色容差|Tolerancia de color|Tolérance de couleur|Tolleranza colore|色の許容値|Цветовой допуск
        Move the pointer to measure distances between edges. Drag around an object to find its bounds.|移动指针测量边缘间距。框选对象查找边界。|Mueve el cursor para medir entre bordes. Rodea un objeto para hallar sus límites.|Déplacer le pointeur pour mesurer entre les bords. Entourer un objet pour trouver ses limites.|Muovi il puntatore per misurare tra i bordi. Circonda un oggetto per trovarne i limiti.|カーソルでエッジ間の距離を測定。囲むと対象の境界を検出します。|Двигайте указатель для измерения между краями. Обведите объект, чтобы найти его границы.
        Drag an exact rectangle, then move, resize, pin, or copy the measurement.|拖出矩形，然后移动、缩放、固定或复制测量。|Dibuja un rectángulo y muévelo, cambia su tamaño, fíjalo o copia la medida.|Tracer un rectangle, puis déplacer, redimensionner, épingler ou copier la mesure.|Traccia un rettangolo, poi sposta, ridimensiona, fissa o copia la misura.|矩形を描き、移動・サイズ変更・固定・コピーできます。|Выделите прямоугольник, затем перемещайте, меняйте размер, закрепляйте или копируйте измерение.
        Approve Schnaps in System Settings → Login Items.|在系统设置 → 登录项中批准 Schnaps。|Autoriza Schnaps en Ajustes del Sistema → Ítems de inicio.|Autoriser Schnaps dans Réglages Système → Ouverture.|Approva Schnaps in Impostazioni di Sistema → Elementi login.|システム設定 → ログイン項目で Schnaps を許可してください。|Разрешите Schnaps в Системных настройках → Объекты входа.
        Open Screen Recording Settings…|打开屏幕录制设置…|Abrir ajustes de grabación…|Ouvrir les réglages d’enregistrement…|Apri impostazioni registrazione…|画面収録の設定を開く…|Открыть настройки записи экрана…
        Allow Screen Recording…|允许屏幕录制…|Permitir grabación de pantalla…|Autoriser l’enregistrement de l’écran…|Consenti registrazione schermo…|画面収録を許可…|Разрешить запись экрана…
        Open Settings…|打开设置…|Abrir ajustes…|Ouvrir les réglages…|Apri impostazioni…|設定を開く…|Открыть настройки…
        Allow Screen Recording to Find Dimensions|允许屏幕录制以查找尺寸|Permite grabar la pantalla para buscar dimensiones|Autoriser l’enregistrement pour trouver les dimensions|Consenti la registrazione per trovare le dimensioni|寸法検出には画面収録を許可してください|Разрешите запись экрана для поиска размеров
        Schnaps uses a still image of your screen to find edges. Allow access, or measure an area manually.|Schnaps 使用屏幕图像检测边缘。允许访问或手动测量区域。|Schnaps usa una imagen de la pantalla para detectar bordes. Permite el acceso o mide un área manualmente.|Schnaps utilise une image de l’écran pour détecter les bords. Autoriser l’accès ou mesurer une zone manuellement.|Schnaps usa un’immagine dello schermo per rilevare i bordi. Consenti l’accesso o misura un’area manualmente.|Schnaps は画面画像からエッジを検出します。許可するか、領域を手動で測定してください。|Schnaps использует снимок экрана для поиска краёв. Разрешите доступ или измерьте область вручную.
        Screen Recording is needed for screenshots.|截图需要屏幕录制权限。|Las capturas necesitan permiso de grabación.|Les captures nécessitent l’autorisation d’enregistrement.|Gli screenshot richiedono il permesso di registrazione.|画像の保存には画面収録の許可が必要です。|Для снимков нужно разрешение записи экрана.
        Select an area or point between edges first.|请先选择区域或将指针放在边缘之间。|Selecciona un área o apunta entre bordes.|Sélectionner une zone ou pointer entre les bords.|Seleziona un’area o punta tra i bordi.|領域を選択するか、エッジの間にカーソルを置いてください。|Выберите область или наведите указатель между краями.
        The screenshot could not be encoded.|无法编码截图。|No se pudo codificar la captura.|Impossible d’encoder la capture.|Impossibile codificare lo screenshot.|画像を変換できませんでした。|Не удалось закодировать снимок.
        Screenshot failed|截图失败|Error de captura|Échec de la capture|Screenshot non riuscito|画像の保存に失敗|Ошибка снимка
        Toggle screenshot padding|切换截图留白|Alternar margen de captura|Changer la marge de capture|Cambia margine screenshot|画像の余白を切り替え|Переключить отступ снимка
        Screen points|屏幕点|Puntos de pantalla|Points de l’écran|Punti schermo|画面のポイント|Пункты экрана
        Measurement pinned|测量已固定|Medida fijada|Mesure épinglée|Misura fissata|測定を固定しました|Измерение закреплено
        Horizontal distance pinned|水平距离已固定|Distancia horizontal fijada|Distance horizontale épinglée|Distanza orizzontale fissata|横の距離を固定しました|Горизонтальное расстояние закреплено
        Vertical distance pinned|垂直距离已固定|Distancia vertical fijada|Distance verticale épinglée|Distanza verticale fissata|縦の距離を固定しました|Вертикальное расстояние закреплено
        Measurements cleared|测量已清除|Medidas borradas|Mesures effacées|Misure cancellate|測定を消去しました|Измерения очищены
        Distance copied|距离已复制|Distancia copiada|Distance copiée|Distanza copiata|距離をコピーしました|Расстояние скопировано
        Move the pointer or drag a region first|请先移动指针或拖出区域|Mueve el cursor o dibuja una región primero|Déplacer le pointeur ou tracer une zone d’abord|Muovi il puntatore o traccia un’area prima|カーソルを動かすか領域を描いてください|Сначала переместите указатель или выделите область
        Capture unavailable. R to retry, S to measure an area.|截图不可用。R 重试，S 测量区域。|Captura no disponible. R reintenta, S mide un área.|Capture indisponible. R pour réessayer, S pour mesurer une zone.|Cattura non disponibile. R riprova, S misura un’area.|画面を取得できません。R で再試行、S で領域測定。|Захват недоступен. R — повторить, S — измерить область.
        """
}
