# Plotly figures. Inputs are produced by 01_analyze.R.
payload <- lapply(windows, function(z) {
  endpoint <- tail(z, 1); b <- as.character(z$baseline[1])
  hover_wage <- sprintf("%s<br>Average hourly pay: $%.2f<br>Pay index: %.2f<br>Starting month: %s", month_label(z$date), z$hourly_wage, z$wage_index, month_label(b))
  hover_price <- ifelse(is.na(z$cpi), "CPI unavailable", sprintf("%s<br>CPI: %.3f<br>Price index: %.2f<br>Starting month: %s", month_label(z$date), z$cpi, z$price_index, month_label(b)))
  hover_real <- sprintf("%s<br>Purchasing-power change: %+.2f%%<br>Hourly pay in starting-month dollars: $%.2f<br>Starting month: %s", month_label(z$date), z$real_change_pct, z$real_hourly_base_dollars, month_label(b))
  list(date = as.character(z$date), wage = z$wage_index, price = z$price_index,
       real = z$real_change_pct, wage_hover = hover_wage, price_hover = hover_price, real_hover = hover_real,
       colors = ifelse(is.na(z$real_change_pct), "#aaaaaa", ifelse(z$real_change_pct >= 0, "#007F73", "#C44E36")),
       summary = sprintf("%s to %s | Hourly pay %+.1f%% | Prices %+.1f%% | Purchasing power %+.1f%%",
         month_label(b), month_label(endpoint$date), endpoint$wage_index - 100, endpoint$price_index - 100, endpoint$real_change_pct))
})
# Build one self-contained Plotly document. No htmlwidgets binding or CDN is
# required by the displayed charts; both panels share a single script context.
# Use the bundled, verified Plotly release on every machine. Do not discover
# JavaScript inside the locally installed R package (its contents vary).
js_file <- "code/lib/plotly-2.11.1.min.js"
if (!file.exists(js_file)) stop("Missing code/lib/plotly-2.11.1.min.js. Copy the complete post7 folder.")
# Read bytes, not a locale-dependent R character string. Some digest versions
# translate character input to the system encoding before hashing on Windows.
# Normalize CRLF only; preserve the UTF-8 JavaScript bytes everywhere else.
plotly_bytes <- readBin(js_file, what = "raw", n = file.info(js_file)$size)
crlf_cr <- which(plotly_bytes == as.raw(13L))
crlf_cr <- crlf_cr[crlf_cr < length(plotly_bytes)]
crlf_cr <- crlf_cr[plotly_bytes[crlf_cr + 1L] == as.raw(10L)]
if (length(crlf_cr)) plotly_bytes <- plotly_bytes[-crlf_cr]
expected_js_hash <- "f33191858012cf263ca873b819c5e7405538183fe3d0e1a6d7b3e577867bcc37"
actual_js_hash <- digest::digest(plotly_bytes, algo = "sha256", serialize = FALSE)
if (actual_js_hash != expected_js_hash) stop(paste0(
  "Plotly byte checksum mismatch. Expected ", expected_js_hash,
  "; got ", actual_js_hash, ". Copy code/lib/plotly-2.11.1.min.js from the ZIP."))
options_html <- paste(vapply(names(payload), function(b) sprintf('<option value="%s"%s>%s</option>', b,
  if (b == "2021-01-01") ' selected="selected"' else "", month_label(b)), character(1)), collapse = "")
payload_json <- jsonlite::toJSON(payload, auto_unbox = TRUE, na = "null", digits = NA)
app_script <- '
(function() {
  "use strict";
  const windows = JSON.parse(document.getElementById("chart-data").textContent);
  const selector = document.getElementById("blog7-baseline");
  const upper = document.getElementById("wage-price-plot");
  const lower = document.getElementById("real-pay-plot");
  const summary = document.getElementById("blog7-summary");
  const status = document.getElementById("chart-status");
  function fitFrame() {
    try {
      const height=Math.ceil(document.querySelector("main").getBoundingClientRect().height+8);
      if(window.parent!==window)window.parent.postMessage({type:"blog7-chart-height",height:height},"*");
    } catch(error) { /* Standalone or cross-origin display keeps its default height. */ }
  }
  if(typeof ResizeObserver!=="undefined")new ResizeObserver(fitFrame).observe(document.querySelector("main"));
  window.addEventListener("resize",()=>setTimeout(fitFrame,100));
  const config = {responsive:true, displaylogo:false, scrollZoom:false,
    modeBarButtonsToRemove:["select2d","lasso2d"]};
  const font = {family:"Arial, sans-serif", size:13, color:"#263447"};
  function upperLayout(d) {return {
    font:font, paper_bgcolor:"white", plot_bgcolor:"#f8fafc",
    margin:{l:58,r:16,t:42,b:55},
    xaxis:{type:"date",title:"Month",range:[d.date[0],d.date[d.date.length-1]],
      rangeslider:{visible:true,thickness:0.13,range:[d.date[0],d.date[d.date.length-1]]},gridcolor:"#e2e8f0"},
    yaxis:{title:"Index (starting month = 100)",gridcolor:"#e2e8f0",zeroline:false},
    legend:{orientation:"h",x:0,y:1.02,yanchor:"bottom"},hovermode:"x unified",
    shapes:[{type:"line",xref:"paper",x0:0,x1:1,y0:100,y1:100,line:{color:"#94a3b8",width:1,dash:"dot"}}]
  };}
  function lowerLayout(d) {return {
    font:font,paper_bgcolor:"white",plot_bgcolor:"#f8fafc",margin:{l:63,r:16,t:15,b:48},
    xaxis:{type:"date",title:"Month",range:[d.date[0],d.date[d.date.length-1]],gridcolor:"#e2e8f0"},
    yaxis:{title:"Purchasing-power change (%)",ticksuffix:"%",gridcolor:"#e2e8f0",zeroline:true,zerolinecolor:"#475569",zerolinewidth:1.5},
    showlegend:false,hovermode:"closest"
  };}
  function upperData(d) {return [
    {x:d.date,y:d.wage,type:"scatter",mode:"lines",name:"Hourly pay",line:{color:"#0072B2",width:3},text:d.wage_hover,hovertemplate:"%{text}<extra></extra>",connectgaps:false},
    {x:d.date,y:d.price,type:"scatter",mode:"lines",name:"Consumer prices",line:{color:"#D55E00",width:3,dash:"dash"},text:d.price_hover,hovertemplate:"%{text}<extra></extra>",connectgaps:false}
  ];}
  function lowerData(d) {return [{x:d.date,y:d.real,type:"bar",name:"Purchasing-power change",marker:{color:d.colors},text:d.real_hover,hovertemplate:"%{text}<extra></extra>"}];}
  async function applyBase(base) {
    const d=windows[base];if(!d)return;
    selector.value=base;summary.textContent=d.summary;
    await Plotly.react(upper,upperData(d),upperLayout(d),config);
    await Plotly.react(lower,lowerData(d),lowerLayout(d),config);
    status.hidden=true;
    document.body.dataset.ready="true";
    requestAnimationFrame(fitFrame);
  }
  async function start() {
    if(typeof Plotly === "undefined") throw new Error("Embedded Plotly library did not load.");
    await applyBase("2021-01-01");
    selector.addEventListener("change",()=>applyBase(selector.value).catch(showError));
    document.querySelectorAll("[data-blog7-base]").forEach(button=>button.addEventListener("click",()=>applyBase(button.dataset.blog7Base).catch(showError)));
    upper.on("plotly_relayout",function(e) {
      let range=e["xaxis.range"];
      if(!range && e["xaxis.range[0]"]!==undefined)range=[e["xaxis.range[0]"],e["xaxis.range[1]"]];
      if(range)Plotly.relayout(lower,{"xaxis.range":range});
      else if(e["xaxis.autorange"])Plotly.relayout(lower,{"xaxis.autorange":true});
    });
  }
  function showError(error) {
    status.hidden=false;status.textContent="Chart loading error: "+error.message;
    console.error(error);
  }
  start().catch(showError);
})();'
app_html <- paste0('<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">',
'<title>Hourly wages and purchasing power</title><style>',
'html,body{margin:0;padding:0;background:white;color:#263447;font:15px/1.5 Arial,sans-serif;}*{box-sizing:border-box;}main{padding:8px 4px;}h3{font-size:16px;margin:12px 0 4px;}select,button{font:inherit;border:1px solid #aab3bd;border-radius:4px;padding:5px 8px;background:white;max-width:100%;}button{background:#f1f5f9;cursor:pointer;}button:hover{background:#e2e8f0}.presets{display:flex;flex-wrap:wrap;gap:6px;margin:8px 0}#blog7-summary{font-size:13px;color:#44546a;min-height:40px;margin:8px 0}#wage-price-plot{width:100%;height:390px}#real-pay-plot{width:100%;height:300px}.note{font-size:12px;color:#536174;margin:2px 6px 10px}#chart-status{padding:10px;background:#fff2cf}@media(max-width:500px){#wage-price-plot{height:410px}#real-pay-plot{height:310px}}',
'</style><script src="data:application/javascript;base64,',base64enc::base64encode(plotly_bytes),'"></script></head><body><main>',
'<label for="blog7-baseline">Compare from: </label><select id="blog7-baseline">', options_html,'</select>',
'<div class="presets"><button type="button" data-blog7-base="2019-12-01">December 2019</button><button type="button" data-blog7-base="2021-01-01">January 2021</button><button type="button" data-blog7-base="2022-06-01">June 2022</button></div>',
'<p id="blog7-summary" aria-live="polite"></p><p id="chart-status" role="status">Loading charts...</p>',
'<h3>1. Hourly pay and consumer prices</h3><div id="wage-price-plot" role="img" aria-label="Indexed hourly wages and consumer prices"></div>',
'<p class="note">Both series equal 100 in the selected starting month. The date slider changes the visible window in both panels.</p>',
'<h3>2. Purchasing-power change</h3><div id="real-pay-plot" role="img" aria-label="Purchasing-power change relative to the selected starting month"></div>',
'<p class="note">Green bars show gains; red bars show losses. Missing observations remain gaps.</p>',
'</main><script id="chart-data" type="application/json">',payload_json,'</script><script>',app_script,'</script></body></html>')
writeLines(app_html, "results/figures/01_wages_prices.html", useBytes = TRUE)
# The article embeds the entire document, so no dependency folders or relative
# figure URLs need to survive website publication.
dashboard_base64 <- base64enc::base64encode(charToRaw(enc2utf8(app_html)))
# A short bootstrap avoids huge entity-escaped script content and data-URL
# navigation limits. The decoded dashboard stays wholly inside the frame.
dashboard_bootstrap <- paste0('<script>document.open();document.write(new TextDecoder().decode(Uint8Array.from(atob("',
  dashboard_base64, '"),function(c){return c.charCodeAt(0)})));document.close();</script>')
dashboard_embed <- paste0('<iframe id="blog7-chart-frame" title="Interactive wages and prices explorer" class="blog7-explorer" style="display:block;width:100%;height:1140px;border:0;" srcdoc="',
  htmltools::htmlEscape(dashboard_bootstrap, attribute = TRUE), '"></iframe><script>window.addEventListener("message",function(e){var f=document.getElementById("blog7-chart-frame");if(f && e.source===f.contentWindow && e.data && e.data.type==="blog7-chart-height" && Number.isFinite(e.data.height)){f.style.height=Math.max(600,Math.min(1800,e.data.height))+"px";}});</script>')
jsonlite::write_json(payload, "results/tables/interactive_data.json", auto_unbox = TRUE, na = "null", digits = NA)
