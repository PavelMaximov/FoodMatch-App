import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/data/models/match_history.dart';
import 'package:food_match/features/profile/presentation/screens/profile_detail_screens.dart';

MatchHistorySession _session(String id,MatchHistoryMode mode)=>MatchHistorySession(sessionId:id,mode:mode,startedAt:DateTime(2026),completedAt:DateTime(2026),partnerName:null,dishCount:0,previewDishes:const [],dishes:const []);
void main(){testWidgets('stale history detail cannot replace newly requested session',(tester)async{final requests=<String,Completer<MatchHistorySession?>>{};Future<MatchHistorySession?> load(String id)=>(requests[id]??=Completer()).future;await tester.pumpWidget(MaterialApp(home:MatchHistorySessionScreen(key:const ValueKey('detail'),sessionId:'old',loader:load)));await tester.pumpWidget(MaterialApp(home:MatchHistorySessionScreen(key:const ValueKey('detail'),sessionId:'new',loader:load)));requests['new']!.complete(_session('new',MatchHistoryMode.solo));await tester.pump();requests['old']!.complete(_session('old',MatchHistoryMode.pair));await tester.pump();expect(find.text('Solo Session'),findsOneWidget);expect(find.text('Pair Session'),findsNothing);});}
