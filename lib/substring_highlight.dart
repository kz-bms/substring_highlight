library substring_highlight;

import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'colors.dart';

final int __int64MaxValue = double.maxFinite.toInt();

/// Widget that renders a string with sub-string highlighting.
class SubstringHighlight extends StatelessWidget {
  SubstringHighlight(
      {this.caseSensitive = false,
      this.maxLines,
      this.overflow = TextOverflow.clip,
      this.term,
      this.terms,
      required this.text,
      this.textAlign = TextAlign.left,
      this.textStyle = const TextStyle(
        color: Colors.black,
      ),
      this.textStyleHighlight = const TextStyle(
        color: Colors.red,
      ),
      this.wordDelimiters = ' .,;?!<>[]~`@#\$%^&*()+-=|\/_',
      this.words =
          false // default is to match substrings (hence the package name!)

      })
      : assert(term != null || terms != null);

  /// By default the search terms are case insensitive.  Pass false to force case sensitive matches.
  final bool caseSensitive;

  /// How visual overflow should be handled.
  final TextOverflow overflow;

  /// An optional maximum number of lines for the text to span, wrapping if necessary.
  /// If the text exceeds the given number of lines, it will be truncated according
  /// to [overflow].
  ///
  /// If this is 1, text will not wrap. Otherwise, text will be wrapped at the
  /// edge of the box.
  final int? maxLines;

  /// The sub-string that is highlighted inside {SubstringHighlight.text}.  (Either term or terms must be passed.  If both are passed they are combined.)
  final String? term;

  /// The array of sub-strings that are highlighted inside {SubstringHighlight.text}.  (Either term or terms must be passed.  If both are passed they are combined.)
  final List<String>? terms;

  /// The String searched by {SubstringHighlight.term} and/or {SubstringHighlight.terms} array.
  final String text;

  /// How the text should be aligned horizontally.
  final TextAlign textAlign;

  /// The {TextStyle} of the {SubstringHighlight.text} that isn't highlighted.
  final TextStyle textStyle;

  /// The {TextStyle} of the {SubstringHighlight.term}/{SubstringHighlight.ters} matched.
  final TextStyle textStyleHighlight;

  /// String of characters that define word delimiters if {words} flag is true.
  final String wordDelimiters;

  /// If true then match complete words only (instead of characters or substrings within words).  This feature is in ALPHA... use 'words' AT YOUR OWN RISK!!!
  final bool words;

  final RegExp regexEmoji = RegExp(
      r'(\u00a9|\u00ae|[\u2000-\u3300]|\ud83c[\ud000-\udfff]|\ud83d[\ud000-\udfff]|\ud83e[\ud000-\udfff])');

  Map<String, TextStyle> textStylePattern = {

    r'(^\*|(?<=\s)\*)[^ \t](.*?)[^ \t]+\*': const TextStyle(
      fontWeight: FontWeight.bold,
    ),
    r'(^\_|(?<=\s)\_)[^ \t](.*?)[^ \t]+\_': const TextStyle(
      fontStyle: FontStyle.italic,
    ),
    r'(^\-|(?<=\s)\-)[^ \t](.*?)[^ \t]+\-': const TextStyle(
      decoration: TextDecoration.underline,
    ),
    r'(^\#|(?<=\s)\#)[^ \t](.*?)[^ \t]+\#': const TextStyle(
      color: Color(ColorsConst.kzRed),
    ),
    r'(^\%|(?<=\s)\%)[^ \t](.*?)[^ \t]+\%': const TextStyle(
      color: Color(ColorsConst.kzGreen),
    ),
    r'(^\!|(?<=\s)\!)[^ \t](.*?)[^ \t]+\!': const TextStyle(
      color: Color(ColorsConst.kzBlue),
    )
  };

  RegExp fileTypeRegex = RegExp(
      '^.*\.(jpg|jpeg|png|gif|raw|tiff|psd|doc|docx|html|css|xls|xlsx|ppt|pptx|zip|pdf|txt|opus|mp3|mp4|mov|avi|m4a|wav)\$',
      caseSensitive: false);

  final urlRegex = RegExp(
      r'''((https?:\/\/)?(www\.)?[-a-zA-Z0-9@:%._\+~#=]{2,256}\.[a-z]{2,4}\b([-a-zA-Z0-9@:%_\+.~#?&//="'`]*))''',
      caseSensitive: false,
      dotAll: true);

  @override
  Widget build(BuildContext context) {
    final String textLC = caseSensitive ? text : text.toLowerCase();

    // corner case: if both term and terms array are passed then combine
    final List<String> termList = [term ?? '', ...(terms ?? [])];

    // remove empty search terms ('') because they cause infinite loops
    final List<String> termListLC = termList
        .where((s) => s.isNotEmpty)
        .map((s) => caseSensitive ? s : s.toLowerCase())
        .toList();

    List<InlineSpan> children = [];

    int start = 0;
    int idx = 0; // walks text (string that is searched)
    while (idx < textLC.length) {
      // print('=== idx=$idx');

      nonHighlightAdd(int end) {
        return children.add(getTextWidget(text: text.substring(start, end)));
      }

      // find index of term that's closest to current idx position
      int iNearest = -1;
      int idxNearest = __int64MaxValue;
      for (int i = 0; i < termListLC.length; i++) {
        // print('*** i=$i');
        int at;
        if ((at = textLC.indexOf(termListLC[i], idx)) >= 0) //MAGIC//CORE
        {
          // print('idx=$idx i=$i at=$at => FOUND: ${termListLC[i]}');

          if (words) {
            if (at > 0 &&
                !wordDelimiters.contains(
                    textLC[at - 1])) // is preceding character a delimiter?
            {
              // print('disqualify preceding: idx=$idx i=$i');
              continue; // preceding character isn't delimiter so disqualify
            }

            int followingIdx = at + termListLC[i].length;
            if (followingIdx < textLC.length &&
                !wordDelimiters.contains(textLC[
                    followingIdx])) // is character following the search term a delimiter?
            {
              // print('disqualify following: idx=$idx i=$i');
              continue; // following character isn't delimiter so disqualify
            }
          }

          // print('term #$i found at=$at (${termListLC[i]})');
          if (at < idxNearest) {
            // print('PEG');
            iNearest = i;
            idxNearest = at;
          }
        }
      }

      if (iNearest >= 0) {
        // found one of the terms at or after idx
        // iNearest is the index of the closest term at or after idx that matches

        // print('iNearest=$iNearest @ $idxNearest');
        if (start < idxNearest) {
          // we found a match BUT FIRST output non-highlighted text that comes BEFORE this match
          nonHighlightAdd(idxNearest);
          start = idxNearest;
        }

        // output the match using desired highlighting
        int termLen = termListLC[iNearest].length;
        children.add(TextSpan(
            text: text.substring(start, idxNearest + termLen),
            style: textStyleHighlight));
        start = idx = idxNearest + termLen;
      } else {
        if (words) {
          idx++;
          nonHighlightAdd(idx);
          start = idx;
        } else {
          // if none match at all (ever!)
          // --or--
          // one or more matches but during this iteration there are NO MORE matches
          // in either case, add reminder of text as non-highlighted text
          nonHighlightAdd(textLC.length);
          break;
        }
      }
    }

    return RichText(
        maxLines: maxLines,
        overflow: overflow,
        text: TextSpan(children: children, style: textStyle),
        textAlign: textAlign,
        textScaleFactor: MediaQuery.of(context).textScaleFactor);
  }

  TextSpan getTextWidget({
    required String text,
    TextStyle? style,
  }) {
    TextStyle? textStyle = const TextStyle();
    List<TextSpan> child = [];

    var pattern = RegExp(
        textStylePattern.keys.map((key) {
          return key;
        }).join('|'),
        multiLine: true);

    text.splitMapJoin(
      pattern,
      onMatch: (Match match) {
        String matchedText = match.group(0).toString();

        TextStyle? textStyle =
        textStylePattern[textStylePattern.keys.firstWhere((e) {
          bool hasMatch = false;
          RegExp(e).allMatches(matchedText).forEach((element) {
            if (element.group(0) == match.group(0)) hasMatch = true;
          });
          return hasMatch;
        })];

        String inputText = matchedText.substring(1, matchedText.length - 1);

        child.add(RegExp(textStylePattern.keys.map((e) => e).join('|'))
                .hasMatch(inputText)
            ? getTextWidget(
                text: inputText,
                style: textStyle != null ? textStyle?.merge(style) : style,
              )
            : TextSpan(
                children: getUrlTextWidget(
                text: inputText,
                style: textStyle != null
                    ? textStyle?.merge(style)
                    : const TextStyle().merge(style),
              )));

        return "";
      },
      onNonMatch: (String text) {
        if (text.isNotEmpty) {
          child.add(TextSpan(
              children: getUrlTextWidget(
                text: text,
                style: style != null ? style.merge(textStyle) : TextStyle(),
              )));
        }
        return "";
      },
    );

    return TextSpan(children: child);
  }


  List<TextSpan> getUrlTextWidget({
    required String text,
    TextStyle? style,
  }) {
    List<TextSpan> span = [];

    text.splitMapJoin(urlRegex, onMatch: (Match match) {
      var fileMatch = fileTypeRegex.firstMatch(match.group(0).toString());
      if (fileMatch != null) {
        span.add(TextSpan(
            children: getTextStyleWidget(
              text,
              style: style ?? const TextStyle(),
            )));
      } else {
        span.add(TextSpan(
          text: match.group(0).toString(),
          style: style != null
              ? style.merge(TextStyle(
              decoration: TextDecoration.underline, color: Colors.blue))
              : TextStyle(
              decoration: TextDecoration.underline, color: Colors.blue),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              Uri url = Uri.parse(text);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              } else if (text.contains('@')) {
                // Handle email address here
                String email = text;
                final Uri emailUrl = Uri(
                  scheme: 'mailto',
                  path: email,
                );
                await launchUrl(emailUrl);
              } else {
                await launchUrl(Uri.parse('https://$url'),
                    mode: LaunchMode.externalApplication);
              }
            },
        ));
      }
      return '';
    }, onNonMatch: (String text) {
      span.add(TextSpan(
          children: getTextStyleWidget(
            text,
            style: style ?? const TextStyle(),
          )));
      return '';
    });

    return span;
  }

  List<TextSpan> getTextStyleWidget(
    String text, {
    required TextStyle style,
  }) {
    List<TextSpan> span = [];
    for (var char in text.characters) {
      span.add(TextSpan(
          text: (term ?? '').isEmpty
              ? char
              : RegExp(r'[\*\_\-\#\%\!]+').allMatches(char).isNotEmpty
                  ? ' '
                  : char,
          style: style.merge(TextStyle(
              fontSize: regexEmoji.allMatches(char).isNotEmpty ? 18 : 14,
              color: style.color ?? Colors.black,
              fontFamily: Platform.isIOS
                  ? regexEmoji.allMatches(char).isNotEmpty
                      ? 'Apple Color Emoji'
                      : ''
                  : ''))));
    }
    return span;
  }
}
