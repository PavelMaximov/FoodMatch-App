import 'package:flutter/material.dart';
import '../../../core/theme/theme_extensions.dart';
class PremiumScreen extends StatelessWidget {const PremiumScreen({super.key});
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('FoodMatch Premium')),body:ListView(padding:const EdgeInsets.all(24),children:<Widget>[
  Icon(Icons.workspace_premium_rounded,size:72,color:context.fmColors.primary),const SizedBox(height:16),const Text('FoodMatch Premium',textAlign:TextAlign.center,style:TextStyle(fontSize:28,fontWeight:FontWeight.w800)),const SizedBox(height:20),
  for(final item in const ['No ads','Advanced filters','Unlimited custom dishes','Session history','Shopping lists'])ListTile(leading:const Icon(Icons.check_circle_outline),title:Text(item)),
  const SizedBox(height:16),const _Plan(title:'Monthly',price:'€3.99 / month'),const SizedBox(height:12),const _Plan(title:'Yearly',price:'€29.99 / year',detail:'7 days free'),const SizedBox(height:20),
  // TODO(IAP): Replace fallback prices and offer text with localized store product metadata.
  const FilledButton(onPressed:null,child:Text('Subscriptions coming soon')),
 ]));}
class _Plan extends StatelessWidget {const _Plan({required this.title,required this.price,this.detail});final String title,price;final String? detail;@override Widget build(BuildContext context)=>Card(child:ListTile(title:Text(title,style:const TextStyle(fontWeight:FontWeight.w700)),subtitle:detail==null?null:Text(detail!),trailing:Text(price,style:const TextStyle(fontWeight:FontWeight.w700)))) ;}
