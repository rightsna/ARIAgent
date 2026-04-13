part of '../schedule_tab.dart';

// ── Layout constants ──────────────────────────────────────
const List<String> _kDayNames = ['일', '월', '화', '수', '목', '금', '토'];
const Color _kAccent = Color(0xFF6C63FF);
const double _kTimeColW = 44.0;  // 하루보기 시간축 너비
const double _kCardW = 80.0;     // 루틴카드 1열 너비
const double _kHourH = 52.0;     // 1시간당 높이
const double _kCardH = 30.0;     // 루틴카드 고정 높이
const double _kCardTopPad = (_kHourH - _kCardH) / 2;
const double _kWeekLabelW = 96.0;
const double _kWeekViewW = _kWeekLabelW + _kCardW * 7; // 656px
const double _kTotalH = 24 * _kHourH;               // 1248px

bool _isIntervalType(String? type) =>
    type == 'every_n_hours' || type == 'every_n_minutes';
