import Foundation

struct Msg: Hashable {
    let text: String
    let source: String?
    init(_ text: String, _ source: String? = nil) { self.text = text; self.source = source }
}

// MARK: - Motivational messages shown when the adhan comes in

enum Motivation {
    static let headlines: [Prayer: [String]] = [
        .fajr: [tr("الصلاة خيرٌ من النوم"), tr("حيّ على الفلاح"), tr("بداية يومك مع ربنا")],
        .dhuhr: [tr("حيّ على الصلاة"), tr("استراحة نص اليوم مع الله"), tr("سيب الشغل شوية")],
        .asr: [tr("حيّ على الصلاة"), tr("الصلاة الوسطى"), tr("قبل ما اليوم يجري")],
        .maghrib: [tr("حيّ على الصلاة"), tr("اليوم خلص… اختمه بسجدة"), tr("وقت المغرب قصير")],
        .isha: [tr("حيّ على الفلاح"), tr("آخر صلاة في يومك"), tr("نام وإنت مطمّن")],
    ]
    static let fridayHeadlines = [tr("الجمعة… خير يوم طلعت عليه الشمس"), tr("فاسعَوا إلى ذكر الله")]

    static let general: [Msg] = [
        Msg(tr("أحبُّ الأعمال إلى الله: الصلاة على وقتها"), tr("متفق عليه")),
        Msg(tr("أقربُ ما يكون العبد من ربه وهو ساجد، فأكثروا الدعاء"), tr("رواه مسلم")),
        Msg(tr("وجُعلت قرّةُ عيني في الصلاة"), tr("رواه النسائي")),
        Msg(tr("أرِحنا بها يا بلال"), tr("رواه أبو داود")),
        Msg(tr("إنّ الصلاة كانت على المؤمنين كتابًا موقوتًا"), tr("النساء ١٠٣")),
        Msg(tr("واستعينوا بالصبر والصلاة"), tr("البقرة ٤٥")),
        Msg(tr("وأقِم الصلاة لذِكري"), tr("طه ١٤")),
        Msg(tr("قد أفلح المؤمنون ۝ الذين هم في صلاتهم خاشعون"), tr("المؤمنون ١-٢")),
        Msg(tr("ألا بذكر الله تطمئن القلوب"), tr("الرعد ٢٨")),
        Msg(tr("واسجُد واقترب"), tr("العلق ١٩")),
        Msg(tr("إنّ الصلاة تنهى عن الفحشاء والمنكر"), tr("العنكبوت ٤٥")),
        Msg(tr("أول ما يُحاسَب عليه العبد يوم القيامة الصلاة"), tr("رواه الترمذي والنسائي")),
        Msg(tr("مثَل الصلوات الخمس كمثَل نهرٍ جارٍ على باب أحدكم يغتسل منه كل يوم خمس مرات"), tr("رواه مسلم")),
        Msg(tr("الشغل هيستنّاك عشر دقايق… بس اللحظة دي مش هترجع تاني")),
        Msg(tr("إنت بتاخد بريك من الدنيا عشان تكلّم رب الدنيا")),
        Msg(tr("قوم اتوضّى… المية هتصحّيك وتريّح عينك من الشاشة")),
        Msg(tr("كل سجدة بترفعك درجة، وبتحطّ عنك خطيئة")),
        Msg(tr("التصميم ممكن يتعدّل بعدين… الصلاة على وقتها لأ")),
        Msg(tr("أفضل ديدلاين في يومك: الأذان")),
        Msg(tr("ربنا مستنيك دلوقتي… مش محتاج ميعاد")),
        Msg(tr("خمس دقايق بتغسل اللي فات وتفتح باب للي جاي")),
        Msg(tr("الدعوة اللي شايلها في قلبك… قولها وإنت ساجد")),
        Msg(tr("مفيش حاجة في الشاشة دي أهم من اللي مستنيك على السجادة")),
        Msg(tr("البركة في الوقت بتيجي من هنا… صلّي وارجع شغلك أخفّ")),
    ]

    static let byPrayer: [Prayer: [Msg]] = [
        .fajr: [
            Msg(tr("ركعتا الفجر خيرٌ من الدنيا وما فيها"), tr("رواه مسلم")),
            Msg(tr("من صلّى الصبح فهو في ذمّة الله"), tr("رواه مسلم")),
            Msg(tr("بشِّر المشّائين في الظُّلَم إلى المساجد بالنور التام يوم القيامة"), tr("رواه أبو داود والترمذي")),
            Msg(tr("إنّ قرآن الفجر كان مشهودًا"), tr("الإسراء ٧٨")),
            Msg(tr("من صلّى البَرْدَين دخل الجنة"), tr("متفق عليه")),
            Msg(tr("اللي يبدأ يومه بالفجر… يومه كله في حفظ الله")),
        ],
        .dhuhr: [
            Msg(tr("من حافظ على أربع ركعات قبل الظهر وأربع بعدها حرّمه الله على النار"), tr("رواه أبو داود والترمذي")),
            Msg(tr("ساعةٌ تُفتح فيها أبواب السماء، وأحبّ أن يصعد لي فيها عمل صالح"), tr("رواه الترمذي — عن وقت الظهر")),
            Msg(tr("نص اليوم عدّى… جدّد النية وكمّل بالبركة")),
            Msg(tr("الظهر فرصة تقطع زحمة الشغل وترجع أصفى")),
        ],
        .asr: [
            Msg(tr("حافظوا على الصلوات والصلاة الوسطى وقوموا لله قانتين"), tr("البقرة ٢٣٨")),
            Msg(tr("الذي تفوته صلاة العصر كأنما وُتِر أهلَه وماله"), tr("رواه البخاري")),
            Msg(tr("من صلّى البَرْدَين دخل الجنة"), tr("متفق عليه")),
            Msg(tr("العصر بيعدّي بسرعة… الحقها في أول وقتها")),
        ],
        .maghrib: [
            Msg(tr("وسبِّح بحمد ربك قبل طلوع الشمس وقبل الغروب"), tr("ق ٣٩")),
            Msg(tr("وقت المغرب قصير… ما تأجّلش")),
            Msg(tr("اليوم خلص بكل اللي فيه… سلّمه لربنا بسجدة")),
            Msg(tr("بعد الصلاة: أذكار المساء حصنك لليلة كلها")),
        ],
        .isha: [
            Msg(tr("من صلّى العشاء في جماعة فكأنما قام نصف الليل"), tr("رواه مسلم")),
            Msg(tr("آخر صلاة في يومك… اقفل اليوم وإنت راضي")),
            Msg(tr("صلّي العشاء وما تنساش الوتر قبل ما تنام")),
            Msg(tr("نام وإنت متوضّي… وقلبك مطمّن")),
        ],
    ]

    static let friday: [Msg] = [
        Msg(tr("يا أيها الذين آمنوا إذا نودي للصلاة من يوم الجمعة فاسعَوا إلى ذكر الله وذروا البيع"), tr("الجمعة ٩")),
        Msg(tr("خير يومٍ طلعت عليه الشمس يوم الجمعة"), tr("رواه مسلم")),
        Msg(tr("أكثِروا من الصلاة عليّ يوم الجمعة"), tr("رواه أبو داود")),
        Msg(tr("ما تنساش سورة الكهف النهارده… نور ما بين الجمعتين")),
    ]
}

// MARK: - Short adhkar for periodic reminders

enum Adhkar {
    static let reminders: [Msg] = [
        Msg(tr("سبحان الله وبحمده، سبحان الله العظيم"), tr("كلمتان حبيبتان إلى الرحمن — متفق عليه")),
        Msg(tr("لا حول ولا قوة إلا بالله"), tr("كنز من كنوز الجنة — متفق عليه")),
        Msg(tr("أستغفر الله العظيم وأتوب إليه")),
        Msg(tr("اللهم صلِّ وسلِّم وبارك على نبينا محمد")),
        Msg(tr("لا إله إلا أنت سبحانك إني كنت من الظالمين"), tr("دعوة ذي النون")),
        Msg(tr("ربِّ اشرح لي صدري ويسِّر لي أمري"), tr("طه ٢٥-٢٦")),
        Msg(tr("اللهم أعنّي على ذكرك وشكرك وحسن عبادتك"), tr("رواه أبو داود")),
        Msg(tr("حسبي الله لا إله إلا هو عليه توكلت وهو رب العرش العظيم"), tr("التوبة ١٢٩")),
        Msg(tr("اللهم إني أسألك علمًا نافعًا ورزقًا طيبًا وعملًا متقبّلًا"), tr("رواه ابن ماجه")),
        Msg(tr("ربنا آتنا في الدنيا حسنة وفي الآخرة حسنة وقنا عذاب النار"), tr("البقرة ٢٠١")),
        Msg(tr("سبحان الله، والحمد لله، ولا إله إلا الله، والله أكبر"), tr("أحبّ الكلام إلى الله — رواه مسلم")),
        Msg(tr("يا حيّ يا قيّوم برحمتك أستغيث، أصلِح لي شأني كله")),
        Msg(tr("ربِّ زدني علمًا"), tr("طه ١١٤")),
        Msg(tr("اللهم بارك لي في وقتي وشغلي ورزقي")),
    ]

    static let tasbih = [tr("سبحان الله"), tr("الحمد لله"), tr("الله أكبر")]

    /// Short adhkar for the idle notch line (shown most of the time).
    static let dhikr: [Msg] = [
        Msg(tr("سبحان الله وبحمده، سبحان الله العظيم")),
        Msg(tr("سبحان الله، والحمد لله، ولا إله إلا الله، والله أكبر")),
        Msg(tr("لا حول ولا قوة إلا بالله")),
        Msg(tr("أستغفر الله العظيم وأتوب إليه")),
        Msg(tr("اللهم صلِّ وسلِّم على نبينا محمد")),
        Msg(tr("لا إله إلا الله وحده لا شريك له، له الملك وله الحمد")),
        Msg(tr("سبحان الله وبحمده عدد خلقه ورضا نفسه")),
        Msg(tr("الحمد لله حمدًا كثيرًا طيبًا مباركًا فيه")),
        Msg(tr("حسبي الله ونعم الوكيل")),
        Msg(tr("رضيت بالله ربًّا وبالإسلام دينًا وبمحمد ﷺ نبيًّا")),
        Msg(tr("لا إله إلا أنت سبحانك إني كنت من الظالمين")),
        Msg(tr("سبحان الله")),
        Msg(tr("الحمد لله")),
        Msg(tr("الله أكبر")),
        Msg(tr("لا إله إلا الله")),
        Msg(tr("سبحان الله العظيم")),
        Msg(tr("يا حيّ يا قيّوم")),
        Msg(tr("اللهم لك الحمد كما ينبغي لجلال وجهك وعظيم سلطانك")),
        Msg(tr("سبحان الله وبحمده")),
        Msg(tr("سبحان الله والحمد لله")),
        Msg(tr("لا إله إلا الله، محمد رسول الله")),
        Msg(tr("أستغفر الله")),
        Msg(tr("أستغفر الله الذي لا إله إلا هو الحي القيوم وأتوب إليه")),
        Msg(tr("سبحان ربي العظيم")),
        Msg(tr("سبحان ربي الأعلى")),
        Msg(tr("الحمد لله رب العالمين")),
        Msg(tr("الحمد لله على كل حال")),
        Msg(tr("الحمد لله الذي بنعمته تتم الصالحات")),
        Msg(tr("الله أكبر كبيرًا، والحمد لله كثيرًا")),
        Msg(tr("سبحان الله بكرةً وأصيلًا")),
        Msg(tr("لا إله إلا الله الملك الحق المبين")),
        Msg(tr("لا إله إلا الله الحليم الكريم")),
        Msg(tr("سبحان الله العظيم وبحمده")),
        Msg(tr("سبحان القدّوس")),
        Msg(tr("سبحان الملك القدّوس")),
        Msg(tr("سبحان الله عدد ما خلق")),
        Msg(tr("الحمد لله ملء ما خلق")),
        Msg(tr("اللهم صلِّ على محمد وعلى آل محمد")),
        Msg(tr("صلى الله عليه وسلم")),
        Msg(tr("اللهم صلِّ وسلم وبارك على سيدنا محمد")),
        Msg(tr("حسبي الله لا إله إلا هو، عليه توكلت")),
        Msg(tr("توكلت على الله")),
        Msg(tr("ما شاء الله، لا قوة إلا بالله")),
        Msg(tr("إنا لله وإنا إليه راجعون")),
        Msg(tr("رب اغفر لي وتب عليّ إنك أنت التواب الرحيم")),
        Msg(tr("سبحانك اللهم وبحمدك، أشهد أن لا إله إلا أنت")),
        Msg(tr("يا حيّ يا قيوم برحمتك أستغيث")),
        Msg(tr("يا ذا الجلال والإكرام")),
        Msg(tr("لا إله إلا الله العظيم الحليم")),
        Msg(tr("سبحان الله وبحمده عدد خلقه")),
        Msg(tr("سبحان الله زنة عرشه")),
        Msg(tr("سبحان الله مداد كلماته")),
        Msg(tr("الله أكبر، الله أكبر، ولله الحمد")),
        Msg(tr("لا إله إلا الله وحده، صدق وعده، ونصر عبده")),
        Msg(tr("رضيت بالله ربًّا")),
        Msg(tr("اللهم لك الحمد")),
        Msg(tr("ربنا لك الحمد حمدًا كثيرًا طيبًا")),
        Msg(tr("الحمد لله الذي عافاني")),
        Msg(tr("سبحان من سبّح الرعد بحمده")),
        Msg(tr("أستغفر الله وأتوب إليه، مائة مرة في اليوم")),
        Msg(tr("لا إله إلا الله، كلمة التوحيد")),
        Msg(tr("سبحان الله وبحمده، تُمحى بها الخطايا")),
        Msg(tr("الباقيات الصالحات: سبحان الله والحمد لله")),
    ]

    /// Short supplications (shown less often than dhikr).
    static let duas: [Msg] = [
        Msg(tr("ربِّ اشرح لي صدري ويسِّر لي أمري")),
        Msg(tr("اللهم أعنّي على ذكرك وشكرك وحسن عبادتك")),
        Msg(tr("ربنا آتنا في الدنيا حسنة وفي الآخرة حسنة وقنا عذاب النار")),
        Msg(tr("ربِّ زدني علمًا")),
        Msg(tr("اللهم بارك لي في وقتي وشغلي ورزقي")),
        Msg(tr("اللهم إني أسألك علمًا نافعًا ورزقًا طيبًا وعملًا متقبّلًا")),
        Msg(tr("يا مقلّب القلوب ثبّت قلبي على دينك")),
        Msg(tr("اللهم اغفر لي ولوالديّ")),
        Msg(tr("ربِّ اغفر لي ولوالديّ وللمؤمنين")),
        Msg(tr("ربنا لا تزغ قلوبنا بعد إذ هديتنا")),
        Msg(tr("ربنا هب لنا من أزواجنا وذرياتنا قرة أعين")),
        Msg(tr("ربِّ اجعلني مقيم الصلاة ومن ذريتي")),
        Msg(tr("اللهم إني أسألك الهدى والتقى والعفاف والغنى")),
        Msg(tr("اللهم إني أسألك العفو والعافية")),
        Msg(tr("اللهم إنك عفوّ تحب العفو فاعفُ عنا")),
        Msg(tr("اللهم آتِ نفسي تقواها وزكّها أنت خير من زكّاها")),
        Msg(tr("اللهم اكفني بحلالك عن حرامك")),
        Msg(tr("اللهم اغنني بفضلك عمّن سواك")),
        Msg(tr("اللهم إني أعوذ بك من الهم والحزن")),
        Msg(tr("اللهم إني أعوذ بك من العجز والكسل")),
        Msg(tr("ربِّ أوزعني أن أشكر نعمتك")),
        Msg(tr("ربِّ إني لما أنزلت إليّ من خير فقير")),
        Msg(tr("ربنا ظلمنا أنفسنا وإن لم تغفر لنا وترحمنا لنكونن من الخاسرين")),
        Msg(tr("حسبنا الله سيؤتينا الله من فضله")),
        Msg(tr("اللهم أصلح لي ديني الذي هو عصمة أمري")),
        Msg(tr("اللهم اجعل القرآن ربيع قلبي")),
        Msg(tr("اللهم ارزقني حسن الخاتمة")),
        Msg(tr("اللهم اجعل عملي كله خالصًا لوجهك")),
        Msg(tr("اللهم ارزقني الإخلاص في القول والعمل")),
        Msg(tr("اللهم بارك لي فيما رزقتني")),
        Msg(tr("اللهم اجعل شغلي في ميزان حسناتي")),
        Msg(tr("اللهم افتح لي أبواب رحمتك")),
        Msg(tr("ربِّ يسّر ولا تعسّر")),
        Msg(tr("اللهم لا سهل إلا ما جعلته سهلًا")),
        Msg(tr("اللهم اهدني وسدّدني")),
        Msg(tr("اللهم ارحم والديّ كما ربياني صغيرًا")),
        Msg(tr("اللهم تقبّل منا صلاتنا وصيامنا")),
        Msg(tr("اللهم اجعلني من التوابين واجعلني من المتطهرين")),
        Msg(tr("اللهم أجرني من النار")),
        Msg(tr("اللهم إني أسألك الجنة")),
    ]
}

// MARK: - Palestine

enum Palestine {
    /// Short one-line duas for the idle notch strip.
    static let duas: [Msg] = [
        Msg(tr("اللهم انصر أهلنا في فلسطين")),
        Msg(tr("اللهم احفظ غزة وأهلها")),
        Msg(tr("اللهم احفظ المسجد الأقصى وأهله")),
        Msg(tr("اللهم كن لأهل غزة عونًا ونصيرًا")),
        Msg(tr("اللهم ارحم شهداء فلسطين وتقبّلهم")),
        Msg(tr("اللهم داوِ جرحى غزة واشفِ مرضاهم")),
        Msg(tr("اللهم أطعم جائعهم واسقِ عطشانهم")),
        Msg(tr("اللهم آمِن روعاتهم واستر عوراتهم")),
        Msg(tr("اللهم فرّج عن أهل فلسطين عاجلًا")),
        Msg(tr("اللهم ثبّت أقدامهم واربط على قلوبهم")),
        Msg(tr("اللهم ارزقنا صلاةً في المسجد الأقصى")),
        Msg(tr("حسبنا الله ونعم الوكيل")),
        Msg(tr("اللهم انصر المرابطين في بيت المقدس")),
        Msg(tr("اللهم عليك بمن ظلمهم")),
        Msg(tr("اللهم اجبر كسر أهل غزة")),
        Msg(tr("اللهم ارحم أطفال فلسطين واحفظهم")),
        Msg(tr("اللهم ردّ أهل غزة إلى بيوتهم آمنين")),
        Msg(tr("اللهم أنزل على قلوبهم السكينة")),
        Msg(tr("اللهم اجعل لهم من كل همّ فرجًا")),
        Msg(tr("اللهم اكتب للأقصى التحرير")),
    ]

    static let items: [Msg] = [
        Msg(tr("سبحان الذي أسرى بعبده ليلًا من المسجد الحرام إلى المسجد الأقصى الذي باركنا حوله"), tr("الإسراء ١")),
        Msg(tr("اللهم انصر إخواننا في فلسطين وغزة، واربط على قلوبهم، وثبّت أقدامهم")),
        Msg(tr("اللهم احفظ المسجد الأقصى وأهله، وارزقنا فيه صلاةً قبل الممات")),
        Msg(tr("اللهم داوِ جرحاهم، وارحم شهداءهم، وأطعِم جائعهم، وآمِن خوفهم")),
        Msg(tr("ولا تحسبنّ الله غافلًا عمّا يعمل الظالمون"), tr("إبراهيم ٤٢")),
        Msg(tr("ولا تهِنوا ولا تحزنوا وأنتم الأعلَون إن كنتم مؤمنين"), tr("آل عمران ١٣٩")),
        Msg(tr("وكان حقًّا علينا نصرُ المؤمنين"), tr("الروم ٤٧")),
        Msg(tr("مثَل المؤمنين في توادّهم وتراحمهم مثَل الجسد، إذا اشتكى منه عضوٌ تداعى له سائر الجسد"), tr("متفق عليه")),
        Msg(tr("دعوة المرء المسلم لأخيه بظهر الغيب مستجابة"), tr("رواه مسلم")),
        Msg(tr("لا تُشدّ الرحال إلا إلى ثلاثة مساجد: المسجد الحرام، ومسجد الرسول ﷺ، والمسجد الأقصى"), tr("متفق عليه")),
        Msg(tr("خلّي لفلسطين دعوة ثابتة في كل سجدة")),
        Msg(tr("اتصدّق ولو بالقليل عن طريق جهة موثوقة… القليل مع الكثير بيفرق")),
        Msg(tr("علّم ولادك يعني إيه الأقصى… القضية بتعيش بالوعي")),
        Msg(tr("القضية مش خبر عابر… اقرأ عن تاريخ القدس وشاركه")),
        Msg(tr("قاطِع اللي بيدعم الاحتلال… أقل حاجة في إيدك")),
        Msg(tr("حسبنا الله ونعم الوكيل")),
    ]
}

// MARK: - The Muslim ummah

enum Ummah {
    static let duas: [Msg] = [
        Msg(tr("اللهم انصر الإسلام والمسلمين")),
        Msg(tr("اللهم اغفر للمسلمين والمسلمات")),
        Msg(tr("اللهم ألّف بين قلوب المسلمين")),
        Msg(tr("اللهم احفظ بلاد المسلمين")),
        Msg(tr("اللهم فرّج همّ المهمومين من المسلمين")),
        Msg(tr("اللهم اشفِ مرضى المسلمين")),
        Msg(tr("اللهم ارحم موتى المسلمين")),
        Msg(tr("اللهم اجمع كلمة المسلمين على الحق")),
        Msg(tr("اللهم أصلح أحوال المسلمين في كل مكان")),
        Msg(tr("اللهم كن للمستضعفين من المسلمين")),
        Msg(tr("اللهم انصر المظلومين في كل مكان")),
        Msg(tr("اللهم أطعم الجائعين من المسلمين")),
        Msg(tr("اللهم احقن دماء المسلمين")),
        Msg(tr("اللهم ردّ المسلمين إليك ردًّا جميلًا")),
        Msg(tr("اللهم ارفع البلاء عن المسلمين")),
        Msg(tr("اللهم احفظ شباب المسلمين")),
    ]
}

// MARK: - Sunnah fasting days

struct FastingDay {
    let title: String
    let detail: String
    let source: String?
}

enum Fasting {
    /// Reasons to fast on `day` (empty if none or if fasting is prohibited that day).
    static func reasons(for day: Date, hijriAdjust: Int) -> [FastingDay] {
        let h = Hijri.components(day, adjust: hijriAdjust)
        // Eid days and days of tashreeq — no fasting.
        if (h.month == 10 && h.day == 1) || (h.month == 12 && (10...13).contains(h.day)) { return [] }
        if h.month == 9 { return [FastingDay(title: tr("رمضان"), detail: tr("شهر الصيام… تقبّل الله منا ومنكم"), source: nil)] }

        var out: [FastingDay] = []
        if h.month == 12 && h.day == 9 {
            out.append(FastingDay(title: tr("يوم عرفة"), detail: tr("صيامه يكفّر السنة الماضية والباقية"), source: tr("رواه مسلم")))
        } else if h.month == 12 && h.day < 9 {
            out.append(FastingDay(title: tr("العشر من ذي الحجة"), detail: tr("ما من أيامٍ العملُ الصالح فيها أحبّ إلى الله من هذه الأيام"), source: tr("رواه البخاري")))
        }
        if h.month == 1 && h.day == 9 {
            out.append(FastingDay(title: tr("تاسوعاء"), detail: tr("لئن بقيتُ إلى قابلٍ لأصومنّ التاسع"), source: tr("رواه مسلم")))
        }
        if h.month == 1 && h.day == 10 {
            out.append(FastingDay(title: tr("يوم عاشوراء"), detail: tr("صيامه يكفّر السنة التي قبله"), source: tr("رواه مسلم")))
        }
        if (13...15).contains(h.day) {
            out.append(FastingDay(title: trf("الأيام البيض (%@ %@)", AR.num(h.day), Hijri.monthNames[h.month - 1]),
                                  detail: tr("صيام ثلاثة أيام من كل شهر صيام الدهر كله"), source: tr("متفق عليه")))
        }
        if h.month == 10 && h.day >= 2 {
            out.append(FastingDay(title: tr("ست من شوال"), detail: tr("من صام رمضان ثم أتبعه ستًّا من شوال كان كصيام الدهر"), source: tr("رواه مسلم")))
        }
        let weekday = Calendar(identifier: .gregorian).component(.weekday, from: day)
        if weekday == 2 {
            out.append(FastingDay(title: tr("يوم الاثنين"), detail: tr("ذاك يومٌ وُلدتُ فيه، ويومٌ بُعثت فيه"), source: tr("رواه مسلم")))
        } else if weekday == 5 {
            out.append(FastingDay(title: tr("يوم الخميس"), detail: tr("تُعرض الأعمال يوم الاثنين والخميس، فأحبّ أن يُعرض عملي وأنا صائم"), source: tr("رواه الترمذي")))
        }
        if out.isEmpty && h.month == 1 {
            out.append(FastingDay(title: tr("شهر الله المحرّم"), detail: tr("أفضل الصيام بعد رمضان شهر الله المحرّم"), source: tr("رواه مسلم")))
        }
        if out.isEmpty && h.month == 8 {
            out.append(FastingDay(title: tr("شعبان"), detail: tr("كان النبي ﷺ يكثر الصيام في شعبان"), source: tr("متفق عليه")))
        }
        return out
    }
}

// MARK: - Rotation without repeats

/// Picks items at random while avoiding anything shown recently (persisted across launches).
final class Rotator {
    private let key: String
    private let memory: Int
    init(key: String, memory: Int) { self.key = key; self.memory = memory }

    func pick(_ pool: [Msg]) -> Msg {
        guard !pool.isEmpty else { return Msg("") }
        var recent = UserDefaults.standard.stringArray(forKey: key) ?? []
        let limit = min(memory, max(0, pool.count - 1))
        let fresh = pool.filter { !recent.suffix(limit).contains($0.text) }
        let choice = (fresh.isEmpty ? pool : fresh).randomElement()!
        recent.append(choice.text)
        if recent.count > 60 { recent.removeFirst(recent.count - 60) }
        UserDefaults.standard.set(recent, forKey: key)
        return choice
    }
}

enum MessagePicker {
    static let adhanRotator = Rotator(key: "recent.adhan", memory: 20)
    static let dhikrRotator = Rotator(key: "recent.dhikr", memory: 30)
    static let duaRotator = Rotator(key: "recent.dua", memory: 15)
    static let palestineDuaRotator = Rotator(key: "recent.palestineDua", memory: 10)
    static let ummahRotator = Rotator(key: "recent.ummah", memory: 5)
    static let palestineRotator = Rotator(key: "recent.palestine", memory: 8)

    /// A new motivational message for this prayer: prayer-specific ones are favoured, never repeating recent ones.
    static func adhanMessage(for prayer: Prayer, friday: Bool) -> (headline: String, msg: Msg) {
        let specific = (friday && prayer == .dhuhr) ? Motivation.friday : (Motivation.byPrayer[prayer] ?? [])
        // Weight specific messages ×2 so each prayer feels like its own moment.
        let pool = specific + specific + Motivation.general
        let msg = adhanRotator.pick(pool)
        let heads = (friday && prayer == .dhuhr) ? Motivation.fridayHeadlines : (Motivation.headlines[prayer] ?? [tr("حيّ على الصلاة")])
        return (heads.randomElement()!, msg)
    }
}

// MARK: - Where you are in a fasting season (today), and what's coming tomorrow

struct FastingStatus: Equatable {
    let text: String
    var dots = 0        // e.g. 3 for the white days
    var filled = 0      // how many of them have started
}

extension Fasting {
    private static let greg = Calendar(identifier: .gregorian)

    private static func prohibited(_ h: (day: Int, month: Int, year: Int)) -> Bool {
        (h.month == 10 && h.day == 1) || (h.month == 12 && (10...13).contains(h.day))
    }
    private static func whiteDaysOK(_ month: Int) -> Bool { month != 9 }   // in Ramadan the whole month is fasting

    private static func days(_ n: Int) -> String {
        n == 1 ? tr("يوم") : n == 2 ? tr("يومين") : trf("%@ أيام", AR.num(n))
    }

    /// One line for today: "النهارده تاني يوم من الأيام البيض · فاضل بكرة" (+ Monday/Thursday).
    static func status(on day: Date, adjust: Int) -> FastingStatus? {
        let h = Hijri.components(day, adjust: adjust)
        if prohibited(h) { return nil }
        let month = Hijri.monthNames[max(0, min(11, h.month - 1))]
        var main: FastingStatus?
        switch (h.month, h.day) {
        case (9, _):
            main = FastingStatus(text: trf("رمضان · اليوم %@", AR.num(h.day)))
        case (12, 1...8):
            main = FastingStatus(text: trf("العشر من ذي الحجة · اليوم %@ · فاضل %@ لعرفة", AR.num(h.day), days(9 - h.day)))
        case (12, 9):
            main = FastingStatus(text: tr("النهارده يوم عرفة"))
        case (1, 8):
            main = FastingStatus(text: tr("بكرة تاسوعاء، وبعده عاشوراء إن شاء الله"))
        case (1, 9):
            main = FastingStatus(text: tr("النهارده تاسوعاء · بكرة عاشوراء"))
        case (1, 10):
            main = FastingStatus(text: tr("النهارده عاشوراء"))
        case (10, 2...):
            main = FastingStatus(text: tr("أيام الست من شوال"))
        default: break
        }
        if main == nil, whiteDaysOK(h.month), h.month != 12 || h.day >= 14 {
            switch h.day {
            case 12 where h.month != 12:
                main = FastingStatus(text: trf("الأيام البيض بتبدأ بكرة إن شاء الله (١٣–١٥ %@)", month), dots: 3, filled: 0)
            case 13:
                main = FastingStatus(text: tr("النهارده أول يوم من الأيام البيض · فاضل يومين"), dots: 3, filled: 1)
            case 14:
                main = FastingStatus(text: h.month == 12 ? tr("النهارده من الأيام البيض · فاضل بكرة")
                                                         : tr("النهارده تاني يوم من الأيام البيض · فاضل بكرة"), dots: 3, filled: 2)
            case 15:
                main = FastingStatus(text: tr("النهارده آخر يوم من الأيام البيض"), dots: 3, filled: 3)
            default: break
            }
        }
        let wd = greg.component(.weekday, from: day)
        let weekly: String? = wd == 2 ? tr("يوم الاتنين") : wd == 5 ? tr("يوم الخميس") : nil
        if var m = main {
            if let weekly, h.month != 9 { m = FastingStatus(text: m.text + " + " + weekly, dots: m.dots, filled: m.filled) }
            return m
        }
        if let weekly { return FastingStatus(text: trf("النهارده %@ — يوم صيام", weekly)) }
        return nil
    }

    /// The evening reminder, about tomorrow: "بكرة تاني يوم من الأيام البيض".
    static func tomorrowPhrase(after day: Date, adjust: Int) -> String? {
        guard let t = greg.date(byAdding: .day, value: 1, to: day) else { return nil }
        let h = Hijri.components(t, adjust: adjust)
        if prohibited(h) { return nil }
        var parts: [String] = []
        switch (h.month, h.day) {
        case (9, _): parts.append(trf("بكرة اليوم %@ من رمضان", AR.num(h.day)))
        case (12, 1...8): parts.append(trf("بكرة اليوم %@ من العشر من ذي الحجة", AR.num(h.day)))
        case (12, 9): parts.append(tr("بكرة يوم عرفة"))
        case (1, 9): parts.append(tr("بكرة تاسوعاء"))
        case (1, 10): parts.append(tr("بكرة عاشوراء"))
        case (10, 2...): parts.append(tr("بكرة من أيام الست من شوال"))
        default: break
        }
        if parts.isEmpty, whiteDaysOK(h.month), h.month != 12 || h.day >= 14 {
            switch h.day {
            case 13: parts.append(tr("بكرة أول يوم من الأيام البيض"))
            case 14: parts.append(h.month == 12 ? tr("بكرة من الأيام البيض") : tr("بكرة تاني يوم من الأيام البيض"))
            case 15: parts.append(tr("بكرة آخر يوم من الأيام البيض"))
            default: break
            }
        }
        if h.month != 9 {
            let wd = greg.component(.weekday, from: t)
            if wd == 2 { parts.append(parts.isEmpty ? tr("بكرة الاتنين") : tr("يوم الاتنين")) }
            if wd == 5 { parts.append(parts.isEmpty ? tr("بكرة الخميس") : tr("يوم الخميس")) }
        }
        return parts.isEmpty ? nil : parts.joined(separator: " + ")
    }
}
