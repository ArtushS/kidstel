import '../story/services/models/generate_story_response.dart';

class PremadeStory {
  final String id;
  final String lang; // 'en' | 'ru' | 'hy'
  final String title;
  final String description;
  final GenerateStoryResponse initial;

  const PremadeStory({
    required this.id,
    required this.lang,
    required this.title,
    required this.description,
    required this.initial,
  });
}

// Simple built-in catalog so users can start reading instantly.
// NOTE: These are local stories; they do not require network to read.
final List<PremadeStory> premadeStories = <PremadeStory>[
  PremadeStory(
    id: 'premade_en_01',
    lang: 'en',
    title: 'The Little Lantern',
    description: 'A brave lantern helps friends find their way home.',
    initial: GenerateStoryResponse(
      requestId: 'premade',
      storyId: 'premade_en_01',
      chapterIndex: 1,
      progress: 1.0,
      title: 'The Little Lantern',
      text:
          'A tiny lantern lived on a shelf in a quiet village.\n\nOne foggy evening, the lantern heard a soft sniffle outside. It was a lost kitten, shivering under a bench. “I can help,” said the lantern.\n\nThe lantern glowed warm and bright, lighting a small path through the fog. Together, they walked past sleepy houses and whispering trees until the kitten recognized a familiar gate.\n\n“Home!” the kitten cheered. The lantern smiled. “Anytime you need light, I’m here.”',
      image: const GeneratedImage(enabled: false, url: null),
      choices: const <StoryChoiceDto>[],
    ),
  ),
  PremadeStory(
    id: 'premade_en_02',
    lang: 'en',
    title: 'Cloud’s First Snow',
    description: 'A curious cloud learns how snowflakes are made.',
    initial: GenerateStoryResponse(
      requestId: 'premade',
      storyId: 'premade_en_02',
      chapterIndex: 1,
      progress: 1.0,
      title: 'Cloud’s First Snow',
      text:
          'Cloud floated high above the mountains, watching the world sparkle below.\n\n“Why do people smile when it’s cold?” Cloud wondered.\n\nA wise wind whispered, “Because snow is a magic blanket.”\n\nCloud gathered tiny droplets, cooled them gently, and—whoosh!—they turned into shining snowflakes. They danced down in swirls and landed softly on rooftops and pine trees.\n\nDown below, children laughed. Cloud’s heart felt warm, even in winter.',
      image: const GeneratedImage(enabled: false, url: null),
      choices: const <StoryChoiceDto>[],
    ),
  ),
  PremadeStory(
    id: 'premade_en_03',
    lang: 'en',
    title: 'The Pocket Dragon',
    description: 'A tiny dragon discovers kindness is stronger than fire.',
    initial: GenerateStoryResponse(
      requestId: 'premade',
      storyId: 'premade_en_03',
      chapterIndex: 1,
      progress: 1.0,
      title: 'The Pocket Dragon',
      text:
          'Milo found a dragon the size of a plum. It sneezed a warm puff of cinnamon-smoke.\n\n“I’m not scary,” the dragon said. “I’m just… small.”\n\nMilo tucked the dragon safely into a pocket. Together they helped neighbors: warming a cold cup of tea, drying wet mittens, and lighting a candle during a blackout.\n\nAt night, the dragon sighed happily. “Today, my fire did good.”\n\nMilo nodded. “That’s the bravest kind of fire.”',
      image: const GeneratedImage(enabled: false, url: null),
      choices: const <StoryChoiceDto>[],
    ),
  ),
  PremadeStory(
    id: 'premade_en_04',
    lang: 'en',
    title: 'The Quiet Robot',
    description: 'A robot learns to listen with its heart.',
    initial: GenerateStoryResponse(
      requestId: 'premade',
      storyId: 'premade_en_04',
      chapterIndex: 1,
      progress: 1.0,
      title: 'The Quiet Robot',
      text:
          'In a busy workshop, Robot Zed was the quietest machine.\n\nWhile others buzzed and beeped, Zed listened: to ticking clocks, to tapping rain, to sighing tools after a long day.\n\nOne afternoon, a child sat nearby looking sad. Zed rolled over and offered a small note: “I’m here.”\n\nThe child smiled. “Thank you for listening.”\n\nZed’s lights blinked softly. Listening, Zed realized, was its superpower.',
      image: const GeneratedImage(enabled: false, url: null),
      choices: const <StoryChoiceDto>[],
    ),
  ),
  PremadeStory(
    id: 'premade_en_05',
    lang: 'en',
    title: 'The River’s Secret Song',
    description: 'A river teaches a child to stay calm and keep going.',
    initial: GenerateStoryResponse(
      requestId: 'premade',
      storyId: 'premade_en_05',
      chapterIndex: 1,
      progress: 1.0,
      title: 'The River’s Secret Song',
      text:
          'A river sang to the stones as it flowed.\n\n“How do you never give up?” asked Lina.\n\nThe river replied, “I move around big rocks. I rest in quiet pools. Then I continue.”\n\nLina tried it the next day. When homework felt hard, she took a breath, asked for help, and tried again.\n\nThat night, Lina heard the river’s song in her mind: rest, flow, continue.',
      image: const GeneratedImage(enabled: false, url: null),
      choices: const <StoryChoiceDto>[],
    ),
  ),
  PremadeStory(
    id: 'premade_ru_01',
    lang: 'ru',
    title: 'Звёздный карман',
    description:
        'Мальчик находит в кармане маленькую звезду и учится делиться светом.',
    initial: GenerateStoryResponse(
      requestId: 'premade',
      storyId: 'premade_ru_01',
      chapterIndex: 1,
      progress: 1.0,
      title: 'Звёздный карман',
      text:
          'Однажды вечером у Пети в кармане зашуршало. Он удивился и достал… маленькую звезду!\n\n— Я потерялась, — тихо сказала звезда.\n\nПетя аккуратно прикрыл её ладонью и повёл домой по тёмной улице. Звезда светила мягко-мягко, и дорога сразу стала добрее.\n\nУ подъезда Петя увидел соседку: у неё погас фонарик. Петя улыбнулся и приоткрыл ладонь.\n\n— Вот, возьмите немного света.\n\nЗвезда радостно мигнула: делиться светом оказалось самым тёплым чудом.',
      image: const GeneratedImage(enabled: false, url: null),
      choices: const <StoryChoiceDto>[],
    ),
  ),
  PremadeStory(
    id: 'premade_ru_02',
    lang: 'ru',
    title: 'Облачко и снежинки',
    description: 'Любопытное облачко узнаёт, как рождаются снежинки.',
    initial: GenerateStoryResponse(
      requestId: 'premade',
      storyId: 'premade_ru_02',
      chapterIndex: 1,
      progress: 1.0,
      title: 'Облачко и снежинки',
      text:
          'Облачко плыло над городом и смотрело вниз.\n\n— Почему зимой люди улыбаются? — удивлялось оно.\n\nВетер прошептал: — Потому что снег укрывает всё мягким одеялом.\n\nОблачко собралo капельки, охладило их — и вдруг они стали снежинками!\n\nСнежинки кружились, как маленькие танцоры, и тихо садились на крыши и ёлки.\n\n— Я тоже могу дарить радость, — улыбнулось Облачко.',
      image: const GeneratedImage(enabled: false, url: null),
      choices: const <StoryChoiceDto>[],
    ),
  ),
  PremadeStory(
    id: 'premade_hy_01',
    lang: 'hy',
    title: 'Փոքրիկ լույսը',
    description: 'Փոքրիկ լույսը օգնում է ընկերներին գտնել ճանապարհը։',
    initial: GenerateStoryResponse(
      requestId: 'premade',
      storyId: 'premade_hy_01',
      chapterIndex: 1,
      progress: 1.0,
      title: 'Փոքրիկ լույսը',
      text:
          'Մի փոքրիկ լույս ապրում էր դարակին։\n\nՄի օր մառախուղի մեջ կորած ճնճղուկը լաց էր լինում։ «Ես կօգնեմ», ասաց լույսը ու փայլեց մեղմ։\n\nՆրանք քայլեցին մութ ճանապարհով, մինչև ճնճղուկը տեսավ իր տունը։\n\n«Շնորհակալ եմ», ասաց նա։\n\nԼույսը ժպտաց. «Երբ լույս պետք լինի, ես այստեղ եմ»։',
      image: const GeneratedImage(enabled: false, url: null),
      choices: const <StoryChoiceDto>[],
    ),
  ),
  PremadeStory(
    id: 'premade_hy_02',
    lang: 'hy',
    title: 'Քամու երգը',
    description: 'Քամին սովորեցնում է հանգիստ շնչել ու շարունակել։',
    initial: GenerateStoryResponse(
      requestId: 'premade',
      storyId: 'premade_hy_02',
      chapterIndex: 1,
      progress: 1.0,
      title: 'Քամու երգը',
      text:
          'Քամին երգում էր ծառերի մեջ։\n\n«Ինչպե՞ս ես միշտ առաջ գնում», հարցրեց Ալինը։\n\nՔամին շշնջաց. «Երբ դժվար է՝ ես դանդաղում եմ, հետո նորից շարունակվում եմ»։\n\nԱլինը փորձեց նույնը. նա շնչեց խոր, խնդրեց օգնություն և նորից փորձեց։\n\nԵրեկոյան նա լսեց քամու երգը՝ «շնչիր, հանգստացիր, շարունակիր»։',
      image: const GeneratedImage(enabled: false, url: null),
      choices: const <StoryChoiceDto>[],
    ),
  ),
];
