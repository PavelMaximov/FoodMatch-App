import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/features/premium/domain/premium_entry_point.dart';
import 'package:food_match/features/premium/presentation/premium_screen.dart';

void main(){
  for(final entry in PremiumEntryPoint.values){testWidgets('renders contextual copy for ${entry.name}',(tester)async{await tester.pumpWidget(MaterialApp(home:PremiumScreen(entryPoint:entry)));expect(find.text(entry.title),findsOneWidget);expect(find.text(entry.subtitle),findsOneWidget);expect(find.text('Subscriptions coming soon'),findsOneWidget);});}
}
