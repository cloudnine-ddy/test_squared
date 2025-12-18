import '../models/question_model.dart';

const kMockQuestions = [
  QuestionModel(
    id: 'q1',
    paperId: 'paper1',
    topicIds: ['1', 'sub_topic_a'],
    questionNumber: 1,
    content: 'Solve for x: 2x + 5 = 13',
    officialAnswer: 'x = 4',
    aiAnswer: [
      {
        'step': 1,
        'description': 'Subtract 5 from both sides',
        'equation': '2x = 8',
      },
      {
        'step': 2,
        'description': 'Divide both sides by 2',
        'equation': 'x = 4',
      },
    ],
  ),
  QuestionModel(
    id: 'q2',
    paperId: 'paper1',
    topicIds: ['1', '2'],
    questionNumber: 2,
    content: 'Find the area of a rectangle with length 5 and width 3',
    officialAnswer: '15 square units',
    aiAnswer: [
      {
        'step': 1,
        'description': 'Use the area formula',
        'equation': 'Area = length × width',
      },
      {
        'step': 2,
        'description': 'Substitute values',
        'equation': 'Area = 5 × 3 = 15',
      },
    ],
  ),
  QuestionModel(
    id: 'q3',
    paperId: 'paper1',
    topicIds: ['3'],
    questionNumber: 3,
    content: 'Find sin(30°)',
    officialAnswer: '0.5',
    aiAnswer: [],
  ),
  QuestionModel(
    id: 'q4',
    paperId: 'paper2',
    topicIds: ['1', 'sub_topic_b', '4'],
    questionNumber: 1,
    content: 'Differentiate f(x) = x² + 3x',
    officialAnswer: "f'(x) = 2x + 3",
    aiAnswer: [
      {
        'step': 1,
        'description': 'Apply power rule to x²',
        'equation': 'd/dx(x²) = 2x',
      },
      {
        'step': 2,
        'description': 'Apply power rule to 3x',
        'equation': 'd/dx(3x) = 3',
      },
      {
        'step': 3,
        'description': 'Combine results',
        'equation': "f'(x) = 2x + 3",
      },
    ],
  ),
  QuestionModel(
    id: 'q5',
    paperId: 'paper2',
    topicIds: ['2', 'sub_topic_c'],
    questionNumber: 2,
    content: 'Calculate the perimeter of a square with side length 4',
    officialAnswer: '16 units',
    aiAnswer: [],
  ),
  QuestionModel(
    id: 'q6',
    paperId: 'paper2',
    topicIds: ['5', '1'],
    questionNumber: 3,
    content: 'Calculate the mean of [2, 4, 6, 8, 10]',
    officialAnswer: '6',
    aiAnswer: [
      {
        'step': 1,
        'description': 'Sum all values',
        'equation': '2 + 4 + 6 + 8 + 10 = 30',
      },
      {
        'step': 2,
        'description': 'Divide by count',
        'equation': 'Mean = 30 / 5 = 6',
      },
    ],
  ),
  QuestionModel(
    id: 'q7',
    paperId: 'paper3',
    topicIds: ['3', 'sub_topic_d'],
    questionNumber: 1,
    content: 'Find cos(60°)',
    officialAnswer: '0.5',
    aiAnswer: [],
  ),
  QuestionModel(
    id: 'q8',
    paperId: 'paper3',
    topicIds: ['4', 'sub_topic_e'],
    questionNumber: 2,
    content: 'Integrate ∫(2x + 1)dx',
    officialAnswer: 'x² + x + C',
    aiAnswer: [
      {
        'step': 1,
        'description': 'Integrate 2x',
        'equation': '∫2x dx = x²',
      },
      {
        'step': 2,
        'description': 'Integrate 1',
        'equation': '∫1 dx = x',
      },
      {
        'step': 3,
        'description': 'Add constant of integration',
        'equation': 'x² + x + C',
      },
    ],
  ),
];

