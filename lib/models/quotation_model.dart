import 'package:intl/intl.dart';

/// Duty shift of a service line. A line can cover one shift or both.
enum DutyShift {
  day('Day'),
  night('Night');

  const DutyShift(this.label);
  final String label;

  static DutyShift fromName(String? name) =>
      DutyShift.values.firstWhere((s) => s.name == name, orElse: () => DutyShift.day);
}

/// Skill classification of a service line. A line can be quoted as skilled,
/// unskilled, or both — each selected one is ticked in the PDF.
enum SkillLevel {
  skilled('Skilled'),
  unskilled('Unskilled');

  const SkillLevel(this.label);
  final String label;

  static SkillLevel fromName(String? name) =>
      SkillLevel.values.firstWhere((s) => s.name == name, orElse: () => SkillLevel.unskilled);
}

/// Reads a set that may have been stored either as a list of names (current)
/// or as a single name (how it was stored before a line could carry both).
/// Never returns empty — a service line always carries at least one value.
Set<T> _readSet<T>(Object? raw, T Function(String?) parse, T fallback) {
  if (raw is List) {
    final parsed = raw.map((e) => parse(e?.toString())).toSet();
    if (parsed.isNotEmpty) return parsed;
  } else if (raw is String && raw.isNotEmpty) {
    return {parse(raw)};
  }
  return {fallback};
}

class QuotationItem {
  String id;
  int srNo;
  String category;

  /// Shifts this line covers. Always holds at least one.
  Set<DutyShift> shifts;

  /// Skill classifications this line covers. Always holds at least one.
  Set<SkillLevel> skillLevels;

  int dutyHours; // 8 or 12
  int workingDays; // 26 (housekeeping) or 30 (guard)
  String customDutyText;
  double ratePerPerson;
  int quantity;

  QuotationItem({
    required this.id,
    required this.srNo,
    required this.category,
    Set<DutyShift>? shifts,
    Set<SkillLevel>? skillLevels,
    this.dutyHours = 8,
    this.workingDays = 30,
    this.customDutyText = '',
    this.ratePerPerson = 13000.0,
    this.quantity = 1,
  })  : shifts = (shifts == null || shifts.isEmpty) ? {DutyShift.day} : {...shifts},
        skillLevels = (skillLevels == null || skillLevels.isEmpty)
            ? {SkillLevel.unskilled}
            : {...skillLevels};

  /// Formatted duty text, e.g. "8Hrs. * 30 Days"
  String get displayDuty {
    if (customDutyText.trim().isNotEmpty) {
      return customDutyText.trim();
    }
    return '${dutyHours}Hrs. *$workingDays Days';
  }

  bool get coversDay => shifts.contains(DutyShift.day);
  bool get coversNight => shifts.contains(DutyShift.night);
  bool get isSkilled => skillLevels.contains(SkillLevel.skilled);
  bool get isUnskilled => skillLevels.contains(SkillLevel.unskilled);

  /// Selections in a stable order, so the document never reshuffles them.
  List<DutyShift> get orderedShifts =>
      DutyShift.values.where(shifts.contains).toList();

  List<SkillLevel> get orderedSkillLevels =>
      SkillLevel.values.where(skillLevels.contains).toList();

  /// Shift text for the document column: "Day", "Night" or "Day & Night".
  String get shiftLabel => orderedShifts.map((s) => s.label).join(' & ');

  /// Same, but broken over two lines so it fits the narrow Shift column.
  String get shiftLabelWrapped =>
      shifts.length > 1 ? 'Day &\nNight' : shiftLabel;

  /// Skill text for the summary line, e.g. "Skilled & Unskilled".
  String get skillLabel => orderedSkillLevels.map((s) => s.label).join(' & ');

  /// Formatted rate, e.g. "Rs.13000/-"
  String get displayRate {
    final formatter = NumberFormat('#,##,###');
    return 'Rs.${formatter.format(ratePerPerson.toInt())}/-';
  }

  double get totalAmount => ratePerPerson * quantity;

  QuotationItem copyWith({
    String? id,
    int? srNo,
    String? category,
    Set<DutyShift>? shifts,
    Set<SkillLevel>? skillLevels,
    int? dutyHours,
    int? workingDays,
    String? customDutyText,
    double? ratePerPerson,
    int? quantity,
  }) {
    return QuotationItem(
      id: id ?? this.id,
      srNo: srNo ?? this.srNo,
      category: category ?? this.category,
      shifts: shifts ?? this.shifts,
      skillLevels: skillLevels ?? this.skillLevels,
      dutyHours: dutyHours ?? this.dutyHours,
      workingDays: workingDays ?? this.workingDays,
      customDutyText: customDutyText ?? this.customDutyText,
      ratePerPerson: ratePerPerson ?? this.ratePerPerson,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'srNo': srNo,
        'category': category,
        'shifts': orderedShifts.map((s) => s.name).toList(),
        'skillLevels': orderedSkillLevels.map((s) => s.name).toList(),
        'dutyHours': dutyHours,
        'workingDays': workingDays,
        'customDutyText': customDutyText,
        'ratePerPerson': ratePerPerson,
        'quantity': quantity,
      };

  factory QuotationItem.fromJson(Map<String, dynamic> json) => QuotationItem(
        id: json['id'] ?? '',
        srNo: json['srNo'] ?? 1,
        category: json['category'] ?? '',
        // `shift`/`skillLevel` are the single-value keys written before a line
        // could carry both; quotations already in Firestore still use them.
        shifts: _readSet(
          json['shifts'] ?? json['shift'],
          DutyShift.fromName,
          DutyShift.day,
        ),
        skillLevels: _readSet(
          json['skillLevels'] ?? json['skillLevel'],
          SkillLevel.fromName,
          SkillLevel.unskilled,
        ),
        dutyHours: json['dutyHours'] ?? 8,
        workingDays: json['workingDays'] ?? 30,
        customDutyText: json['customDutyText'] ?? '',
        ratePerPerson: (json['ratePerPerson'] as num?)?.toDouble() ?? 0.0,
        quantity: json['quantity'] ?? 1,
      );
}

class QuotationModel {
  String id;
  String refNumber;
  DateTime date;
  String dateStampText;
  bool showDateStamp;

  // Client Details
  String clientName;
  String clientCity;
  String subject;
  String kindAttention;
  String introParagraph;

  // Table items
  List<QuotationItem> items;

  // Notes
  List<String> notes;
  String closingNote;
  String thankingText;
  String forCompanyText;

  // Stamps & Signatures
  bool showSignature;
  bool showRoundStamp;
  bool showAddressStamp;
  bool showIsoBadge;
  String signatoryName;

  // Contact & Office details
  String contactMobile1;
  String contactMobile2;
  String contactEmail;
  String contactWebsite;
  String instagramHandle;
  String registeredOffice;
  String branches;

  QuotationModel({
    required this.id,
    required this.refNumber,
    required this.date,
    required this.dateStampText,
    this.showDateStamp = true,
    required this.clientName,
    required this.clientCity,
    required this.subject,
    required this.kindAttention,
    required this.introParagraph,
    required this.items,
    required this.notes,
    this.closingNote = 'We hope for your earliest & positive response, along with the Work Order.',
    this.thankingText = 'Thanking You,',
    this.forCompanyText = 'For Samarth Security,',
    this.showSignature = true,
    this.showRoundStamp = true,
    this.showAddressStamp = true,
    this.showIsoBadge = true,
    this.signatoryName = 'Akash Gadade',
    this.contactMobile1 = '9960099953',
    this.contactMobile2 = '0233-7964373',
    this.contactEmail = 'samarthmultiservices1100@gmail.com',
    this.contactWebsite = 'www.gadadegroup.in',
    this.instagramHandle = '@gadade_group',
    this.registeredOffice = 'Shop No. 38-2, S. No. 247 A1, 100ft. Road, Abhaynagar, Sangli. Maharashtra - 416 416',
    this.branches = 'Mumbai, Pune Sangli, Satara, Kolhapur, Ahilyanagar, Dharashiv',
  });

  /// Roman numeral for the month of [date] — used inside the reference number.
  static const List<String> _romanMonths = [
    'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X', 'XI', 'XII',
  ];

  static String romanMonth(DateTime d) => _romanMonths[d.month - 1];

  /// Build a reference number in the house format, e.g. `Ref/146/Quots/S/X/2026`.
  static String buildRefNumber(int sequence, DateTime d) =>
      'Ref/$sequence/Quots/S/${romanMonth(d)}/${d.year}';

  /// Inked date-stamp text for a date, e.g. "02 OCT 2026".
  static String buildDateStamp(DateTime d) =>
      DateFormat('dd MMM yyyy').format(d).toUpperCase();

  /// A fresh blank proposal. The date always defaults to today and the
  /// reference number to [sequence] (next unused number from storage).
  factory QuotationModel.defaultTemplate({int sequence = 1, DateTime? today}) {
    final now = today ?? DateTime.now();

    return QuotationModel(
      id: now.millisecondsSinceEpoch.toString(),
      refNumber: buildRefNumber(sequence, now),
      date: now,
      dateStampText: buildDateStamp(now),
      showDateStamp: true,
      clientName: '',
      clientCity: '',
      subject: 'Quotation on Manpower Service Arrangements',
      kindAttention: 'Director',
      introParagraph:
          'We are pleased to forward you the following quotation for outsourced Housekeeping services, offering the most competent and quality-based performance.\n\nWe submit our proposal as follows:',
      items: [
        ServicePresets.presets
            .firstWhere((p) => p.category == 'Security Guard (Male)')
            .toItem(id: 'item_1', srNo: 1),
      ],
      notes: [
        'Revision of the rate is subject to a yearly basis.',
        'Plus Add GST: As Applicable by Govt. Of India.',
        'Plus Add Professional Tax: 200(Per Person)',
      ],
    );
  }

  String get formattedDate => DateFormat('dd/MM/yyyy').format(date);

  /// Signature date always tracks the quotation date.
  String get signatoryDate => formattedDate;

  QuotationModel copyWith({
    String? id,
    String? refNumber,
    DateTime? date,
    String? dateStampText,
    bool? showDateStamp,
    String? clientName,
    String? clientCity,
    String? subject,
    String? kindAttention,
    String? introParagraph,
    List<QuotationItem>? items,
    List<String>? notes,
    String? closingNote,
    String? thankingText,
    String? forCompanyText,
    bool? showSignature,
    bool? showRoundStamp,
    bool? showAddressStamp,
    bool? showIsoBadge,
    String? signatoryName,
    String? contactMobile1,
    String? contactMobile2,
    String? contactEmail,
    String? contactWebsite,
    String? instagramHandle,
    String? registeredOffice,
    String? branches,
  }) {
    return QuotationModel(
      id: id ?? this.id,
      refNumber: refNumber ?? this.refNumber,
      date: date ?? this.date,
      dateStampText: dateStampText ?? this.dateStampText,
      showDateStamp: showDateStamp ?? this.showDateStamp,
      clientName: clientName ?? this.clientName,
      clientCity: clientCity ?? this.clientCity,
      subject: subject ?? this.subject,
      kindAttention: kindAttention ?? this.kindAttention,
      introParagraph: introParagraph ?? this.introParagraph,
      items: items ?? this.items.map((i) => i.copyWith()).toList(),
      notes: notes ?? List<String>.from(this.notes),
      closingNote: closingNote ?? this.closingNote,
      thankingText: thankingText ?? this.thankingText,
      forCompanyText: forCompanyText ?? this.forCompanyText,
      showSignature: showSignature ?? this.showSignature,
      showRoundStamp: showRoundStamp ?? this.showRoundStamp,
      showAddressStamp: showAddressStamp ?? this.showAddressStamp,
      showIsoBadge: showIsoBadge ?? this.showIsoBadge,
      signatoryName: signatoryName ?? this.signatoryName,
      contactMobile1: contactMobile1 ?? this.contactMobile1,
      contactMobile2: contactMobile2 ?? this.contactMobile2,
      contactEmail: contactEmail ?? this.contactEmail,
      contactWebsite: contactWebsite ?? this.contactWebsite,
      instagramHandle: instagramHandle ?? this.instagramHandle,
      registeredOffice: registeredOffice ?? this.registeredOffice,
      branches: branches ?? this.branches,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'refNumber': refNumber,
        'date': date.toIso8601String(),
        'dateStampText': dateStampText,
        'showDateStamp': showDateStamp,
        'clientName': clientName,
        'clientCity': clientCity,
        'subject': subject,
        'kindAttention': kindAttention,
        'introParagraph': introParagraph,
        'items': items.map((i) => i.toJson()).toList(),
        'notes': notes,
        'closingNote': closingNote,
        'thankingText': thankingText,
        'forCompanyText': forCompanyText,
        'showSignature': showSignature,
        'showRoundStamp': showRoundStamp,
        'showAddressStamp': showAddressStamp,
        'showIsoBadge': showIsoBadge,
        'signatoryName': signatoryName,
        'contactMobile1': contactMobile1,
        'contactMobile2': contactMobile2,
        'contactEmail': contactEmail,
        'contactWebsite': contactWebsite,
        'instagramHandle': instagramHandle,
        'registeredOffice': registeredOffice,
        'branches': branches,
      };

  factory QuotationModel.fromJson(Map<String, dynamic> json) {
    final blank = QuotationModel.defaultTemplate();
    final date = json['date'] != null ? DateTime.parse(json['date']) : DateTime.now();

    return QuotationModel(
      id: json['id'] ?? '',
      refNumber: json['refNumber'] ?? '',
      date: date,
      dateStampText: json['dateStampText'] ?? buildDateStamp(date),
      showDateStamp: json['showDateStamp'] ?? true,
      clientName: json['clientName'] ?? '',
      clientCity: json['clientCity'] ?? '',
      subject: json['subject'] ?? '',
      kindAttention: json['kindAttention'] ?? '',
      introParagraph: json['introParagraph'] ?? '',
      items: (json['items'] as List<dynamic>?)
              ?.map((i) => QuotationItem.fromJson(i as Map<String, dynamic>))
              .toList() ??
          [],
      notes: (json['notes'] as List<dynamic>?)?.map((n) => n.toString()).toList() ?? [],
      closingNote: json['closingNote'] ?? blank.closingNote,
      thankingText: json['thankingText'] ?? blank.thankingText,
      forCompanyText: json['forCompanyText'] ?? blank.forCompanyText,
      showSignature: json['showSignature'] ?? true,
      showRoundStamp: json['showRoundStamp'] ?? true,
      showAddressStamp: json['showAddressStamp'] ?? true,
      showIsoBadge: json['showIsoBadge'] ?? true,
      signatoryName: json['signatoryName'] ?? blank.signatoryName,
      contactMobile1: json['contactMobile1'] ?? blank.contactMobile1,
      contactMobile2: json['contactMobile2'] ?? blank.contactMobile2,
      contactEmail: json['contactEmail'] ?? blank.contactEmail,
      contactWebsite: json['contactWebsite'] ?? blank.contactWebsite,
      instagramHandle: json['instagramHandle'] ?? blank.instagramHandle,
      registeredOffice: json['registeredOffice'] ?? blank.registeredOffice,
      branches: json['branches'] ?? blank.branches,
    );
  }
}

/// Predefined standard categories with their business rules
class ServiceCategoryPreset {
  final String category;
  final int defaultDutyHours;
  final int defaultWorkingDays;
  final double defaultRate;
  final SkillLevel defaultSkillLevel;
  final String description;

  const ServiceCategoryPreset({
    required this.category,
    required this.defaultDutyHours,
    required this.defaultWorkingDays,
    required this.defaultRate,
    required this.defaultSkillLevel,
    required this.description,
  });

  QuotationItem toItem({
    required String id,
    required int srNo,
    Set<DutyShift>? shifts,
    Set<SkillLevel>? skillLevels,
  }) {
    return QuotationItem(
      id: id,
      srNo: srNo,
      category: category,
      shifts: shifts ?? {DutyShift.day},
      skillLevels: skillLevels ?? {defaultSkillLevel},
      dutyHours: defaultDutyHours,
      workingDays: defaultWorkingDays,
      ratePerPerson: defaultRate,
    );
  }
}

class ServicePresets {
  /// Label used by the category dropdown for a free-text designation.
  static const String customOption = 'Other (type manually)';

  static const List<ServiceCategoryPreset> presets = [
    ServiceCategoryPreset(
      category: 'Office Boy (Male)',
      defaultDutyHours: 8,
      defaultWorkingDays: 26,
      defaultRate: 11000.0,
      defaultSkillLevel: SkillLevel.unskilled,
      description: 'Office tea/coffee, reception assistance, errand support',
    ),
    ServiceCategoryPreset(
      category: 'Office Boy (Female)',
      defaultDutyHours: 8,
      defaultWorkingDays: 26,
      defaultRate: 11000.0,
      defaultSkillLevel: SkillLevel.unskilled,
      description: 'Office tea/coffee, reception assistance, errand support',
    ),
    ServiceCategoryPreset(
      category: 'Security Guard (Male)',
      defaultDutyHours: 8,
      defaultWorkingDays: 30,
      defaultRate: 13000.0,
      defaultSkillLevel: SkillLevel.skilled,
      description: 'PSARA trained male physical security guard',
    ),
    ServiceCategoryPreset(
      category: 'Security Guard (Female)',
      defaultDutyHours: 8,
      defaultWorkingDays: 30,
      defaultRate: 13500.0,
      defaultSkillLevel: SkillLevel.skilled,
      description: 'PSARA trained female physical security guard',
    ),
    ServiceCategoryPreset(
      category: 'Housekeeping Staff (Male)',
      defaultDutyHours: 8,
      defaultWorkingDays: 26,
      defaultRate: 11500.0,
      defaultSkillLevel: SkillLevel.unskilled,
      description: 'Commercial facility & housekeeping cleaning staff',
    ),
    ServiceCategoryPreset(
      category: 'Housekeeping Staff (Female)',
      defaultDutyHours: 8,
      defaultWorkingDays: 26,
      defaultRate: 11500.0,
      defaultSkillLevel: SkillLevel.unskilled,
      description: 'Commercial facility & housekeeping cleaning staff',
    ),
    ServiceCategoryPreset(
      category: 'Bouncer (Male)',
      defaultDutyHours: 8,
      defaultWorkingDays: 30,
      defaultRate: 18000.0,
      defaultSkillLevel: SkillLevel.skilled,
      description: 'VIP protection, event bouncer, crowd control',
    ),
    ServiceCategoryPreset(
      category: 'Bouncer (Female)',
      defaultDutyHours: 8,
      defaultWorkingDays: 30,
      defaultRate: 18000.0,
      defaultSkillLevel: SkillLevel.skilled,
      description: 'VIP protection, event bouncer, crowd control',
    ),
    ServiceCategoryPreset(
      category: 'Armed Security Guard (Gunman)',
      defaultDutyHours: 8,
      defaultWorkingDays: 30,
      defaultRate: 22000.0,
      defaultSkillLevel: SkillLevel.skilled,
      description: 'Licensed armed security personnel for cash/high security',
    ),
    ServiceCategoryPreset(
      category: 'Security Supervisor',
      defaultDutyHours: 8,
      defaultWorkingDays: 30,
      defaultRate: 16000.0,
      defaultSkillLevel: SkillLevel.skilled,
      description: 'Experienced on-site supervisor for site management',
    ),
  ];

  static ServiceCategoryPreset? findByCategory(String category) {
    for (final p in presets) {
      if (p.category == category) return p;
    }
    return null;
  }

  /// Auto-detect working days: 26 for housekeeping/pantry/office boy, 30 otherwise
  static int detectWorkingDays(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('housekeep') ||
        lower.contains('pantry') ||
        lower.contains('office boy') ||
        lower.contains('cleaning')) {
      return 26;
    }
    return 30;
  }

  /// Auto-detect skill level for a free-typed designation.
  static SkillLevel detectSkillLevel(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('housekeep') ||
        lower.contains('pantry') ||
        lower.contains('office boy') ||
        lower.contains('cleaning') ||
        lower.contains('helper') ||
        lower.contains('peon')) {
      return SkillLevel.unskilled;
    }
    return SkillLevel.skilled;
  }
}
