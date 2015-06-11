define("ace/theme/tea", ["require", "exports", "module", "ace/lib/dom"], function(require, exports, module) {
  var dom;
  exports.isDark = true;
  exports.cssClass = "ace-tea";
  exports.cssText = ".ace_layer, .ace_content {\n    overflow: visible !important;\n}\n\n.ace-tea .ace_gutter {\n  background: #222;\n  color: #444\n}\n\n.ace-tea .ace_print-margin {\n  width: 1px;\n  background: #011e3a\n}\n\n.ace-tea {\n  background-color: #222;\n  color: #FFFFFF\n}\n\n.ace-tea .ace_cursor {\n  color: #FFFFFF\n}\n\n.ace-tea .ace_marker-layer .ace_selection {\n  border-radius: 1px;\n  border: 2px solid rgba(0, 170, 255, 0.75);\n  border-width: 0 0 2px 0\n}\n\n.ace-tea .ace_marker-layer .ace_selection.ace_start.ace_multiline {\n  border-width: 2px 0 0 2px;\n  border-radius: 1px 0 0 0;\n  margin-left: -3px;\n}\n\n.ace-tea .ace_marker-layer .ace_selection.ace_middle {\n  border-width: 0 0 0 2px;\n  border-radius: 0;\n  margin-left: -3px;\n}\n\n.ace-tea .ace_marker-layer .ace_selection.ace_finish {\n  border-width: 0 0 2px 2px;\n  border-radius: 0 0 0 1px;\n  margin-left: -3px;\n}\n\n.ace-tea .ace_marker-layer .ace_active-token {\n  position: absolute;\n  border-radius: 1px;\n  border: 2px solid #194459;/*rgba(0, 170, 255, 0.25);*/\n  border-width: 0 0 2px 0;\n  z-index: 3;\n}\n\n.ace-tea.ace_multiselect .ace_selection.ace_start {\n  box-shadow: 0 0 3px 0px #002240;\n  border-radius: 2px\n}\n\n.ace-tea .ace_marker-layer .ace_step {\n  background: rgb(127, 111, 19)\n}\n\n.ace-tea .ace_marker-layer .ace_bracket {\n  margin: -1px 0 0 -1px;\n  border: 1px solid rgba(255, 255, 255, 0.15)\n}\n\n.ace-tea .ace_marker-layer .ace_active-line {\n  background: rgba(0, 0, 0, 0.35)\n}\n\n.ace-tea .ace_gutter-active-line {\n  background-color: rgba(0, 0, 0, 0.35)\n}\n\n/*.ace-tea .ace_marker-layer .ace_selected-word {\n  border: 1px solid rgba(179, 101, 57, 0.75)\n}*/\n\n.ace-tea .ace_invisible {\n  color: rgba(255, 255, 255, 0.15)\n}\n\n.ace-tea .ace_indent-guide {\n  background: url(data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAACCAYAAACZgbYnAAAAEklEQVQImWNgYGBgYHCLSvkPAAP3AgSDTRd4AAAAAElFTkSuQmCC) right repeat-y\n}\n\n.ace-tea .ace_token_keyword {\n  color: red\n}\n\n.ace-tea .ace_token_numerical {\n  color: #FEDF6B\n}\n\n.ace-tea .ace_token_typename {\n  color: #FEDF6B\n}\n\n.ace-tea .ace_token_label {\n  color: #9C49B6\n}\n\n.ace-tea .ace_token_const {\n  color: #FEDF6B\n}\n\n.ace-tea .ace_token_string {\n  color: #FEDF6B\n}\n\n.ace-tea .ace_token_char {\n  color: #FEDF6B\n}\n\n.ace-tea .ace_token_regex {\n  color: #FEDF6B\n}\n\n.ace-tea .ace_token_paren {\n  color: #444\n}\n\n.ace-tea .ace_token_name {\n  color: #9EE062\n}\n\n.ace-tea .ace_token_recurse {\n  color: #67B3DD\n}\n\n.ace-tea .ace_token_param {\n  color: #FDA947\n}\n\n.ace-tea .ace_token_comment {\n  color: grey\n}\n\n.ace-tea .ace_token_operator {\n  color: #67B3DD\n}\n\n.ace-tea .ace_token_normal {\n  color: white\n}\n\n.ace-tea .ace_token_malformed {\n  color: #880000\n}\n\n.ace-tea .ace_token_fake {\n  background: transparent url(\"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAACCAYAAACZgbYnAAAAEklEQVQImWNgYGBgYHCLSvkPAAP3AgSDTRd4AAAAAElFTkSuQmCC\") no-repeat scroll left center / 0px auto;\n  background-size: 1px 3px;\n}\n";
  dom = require("../lib/dom");
  return dom.importCssString(exports.cssText, exports.cssClass);
});
