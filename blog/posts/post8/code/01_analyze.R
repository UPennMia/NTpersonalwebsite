# Run from post8. Base R; fixed seeds; no data download needed.
for(d in c('data/raw','data/cleaned','results/tables','results/figures')) dir.create(d,recursive=TRUE,showWarnings=FALSE)
RNGkind('Mersenne-Twister','Inversion','Rejection')
seed<-20261026L; n<-2000L; B<-5000L; M<-2000L; BC<-2000L; H<-50000L
# Rounded published aggregates. No original customer-level data are supplied.
p0<-.0168; pbuy<-.0365; pr<-.0058; discount<-7
receipt0<-31.26; receipt_nonredeem<-34.47; receipt_redeem<-31.75
source_url<-'https://thearf-org-unified-admin.s3.amazonaws.com/MSI/2020/06/MSI_Report_19-106-1.pdf'
inputs<-data.frame(quantity=c('control_purchase_rate','coupon_purchase_rate','coupon_redemption_rate','coupon_value','control_buyer_receipt','nonredeemer_buyer_receipt','redeemer_buyer_receipt'),
 value=c(p0,pbuy,pr,discount,receipt0,receipt_nonredeem,receipt_redeem),
 unit=c('fraction','fraction','fraction','USD','USD net of discount','USD net of discount','USD net of discount'),
 source=source_url,location=c('Table 2','Table 2','Table 2','printed p20','printed p24','printed p24','printed p24'),
 provenance='Transcribed rounded published aggregates; not raw customer records')
write.csv(inputs,'data/raw/published_inputs.csv',row.names=FALSE)
# margin is the share of PRE-COUPON sales remaining after product/fulfillment
# variable costs. 10% is a stress-test scenario, NOT an estimate of this retailer.
margin<-.10; campaign_cost<-0
prob1<-c(1-pbuy,pbuy-pr,pr)
gross0<-c(0,receipt0)
gross1<-c(0,receipt_nonredeem,receipt_redeem+discount)
redeem1<-c(0,0,1)
profit0<-margin*gross0
profit1<-margin*gross1-discount*redeem1-campaign_cost
gross_increment<-sum(prob1*gross1)-p0*receipt0
coupon_cost<-discount*pr
truth<-margin*gross_increment-coupon_cost-campaign_cost
threshold<-coupon_cost/gross_increment
write.csv(data.frame(seed,n_per_group=n,bootstrap_reps=B,coverage_trials=M,coverage_reps=BC,null_reps=H,
 scenario_margin=margin,scenario_campaign_cost=campaign_cost,simulation_profit_difference=truth,model_break_even_margin=threshold),
 'data/raw/simulation_design.csv',row.names=FALSE)
set.seed(seed)
z0<-rbinom(n,1,p0)
z1<-sample.int(3,n,replace=TRUE,prob=prob1)
x0<-profit0[z0+1];x1<-profit1[z1]
raw_sim<-data.frame(simulated_customer=seq_len(2*n),group=rep(c('Control','Coupon'),each=n),
 purchased=c(z0,as.integer(z1>1)),redeemed=c(rep(0,n),redeem1[z1]),gross_sales=c(gross0[z0+1],gross1[z1]))
raw_sim$profit<-margin*raw_sim$gross_sales-discount*raw_sim$redeemed-ifelse(raw_sim$group=='Coupon',campaign_cost,0)
write.csv(raw_sim,'data/cleaned/simulated_customers.csv',row.names=FALSE)
est<-mean(x1)-mean(x0)
# Explicit customer-level resampling preserves each customer's sales/redemption pair.
set.seed(seed+1L)
draws<-replicate(B,{
 i0<-sample.int(n,n,replace=TRUE);i1<-sample.int(n,n,replace=TRUE)
 c(gross=mean(gross1[z1[i1]])-mean(gross0[z0[i0]+1]),
   redemption=mean(redeem1[z1[i1]]))
})
boot<-margin*draws[1,]-discount*draws[2,]-campaign_cost
ci<-unname(quantile(boot,c(.025,.975)))
write.csv(data.frame(replicate=seq_len(B),gross_difference=draws[1,],redemption_rate=draws[2,],profit_difference=boot),
 'results/tables/bootstrap.csv',row.names=FALSE)
# Counts implement the same empirical customer bootstrap exactly for finite
# outcome categories; they do not replace bootstrap CIs with normal intervals.
set.seed(seed+2L)
k0<-rbinom(M,n,p0); k1<-rmultinom(M,n,prob1)
coverage<-data.frame(experiment=seq_len(M),lower=NA_real_,upper=NA_real_)
for(i in seq_len(M)){
 b0<-rbinom(BC,n,k0[i]/n)
 b1<-rmultinom(BC,n,k1[,i]/n)
 d<-as.vector(crossprod(profit1,b1))/n-profit0[2]*b0/n
 coverage[i,2:3]<-unname(quantile(d,c(.025,.975)))
}
coverage$covered<-coverage$lower<=truth & coverage$upper>=truth
rate<-mean(coverage$covered);mcse<-sqrt(rate*(1-rate)/M)
write.csv(coverage,'results/tables/coverage.csv',row.names=FALSE)
# Null: equal expected profit, NOT equal purchase probabilities.
# Center each empirical arm at its own mean. Resampling these centered
# distributions gives a zero-mean null difference while retaining dispersion.
# Shifted outcomes are a reference distribution, not actual customer records.
set.seed(seed+3L)
b0<-rbinom(H,n,mean(z0))
b1<-rmultinom(H,n,tabulate(z1,nbins=3)/n)
null<-as.vector(crossprod(profit1,b1))/n-profit0[2]*b0/n-est
pvalue<-(1+sum(abs(null)>=abs(est)-1e-12))/(H+1)
critical<-unname(quantile(abs(null),.95,type=1))
write.csv(data.frame(replicate=seq_len(H),difference=null),'results/tables/null.csv',row.names=FALSE)
# Scenarios recompute the same bootstrap draws; demand is held fixed.
observed_gross<-mean(gross1[z1])-mean(gross0[z0+1])
observed_redeem<-mean(redeem1[z1])
margins<-c(.02,.05,.10,.20,.30,.40)
sens<-do.call(rbind,lapply(margins,function(g){
 d<-g*draws[1,]-discount*draws[2,]
 q<-quantile(d,c(.025,.975))
 data.frame(margin=g,profit_difference=g*observed_gross-discount*observed_redeem,lower=q[1],upper=q[2])
}))
write.csv(sens,'results/tables/margin_sensitivity.csv',row.names=FALSE)
s<-data.frame(n_per_group=n,buyers_control=sum(z0),buyers_coupon=sum(z1>1),redeemers=sum(z1==3),
 margin=margin,mean_control=mean(x0),mean_coupon=mean(x1),difference=est,ci_lower=ci[1],ci_upper=ci[2],
 simulation_truth=truth,coverage=rate,coverage_mcse=mcse,p_value=pvalue,p_mcse=sqrt(pvalue*(1-pvalue)/H),
 critical_abs=critical,null_rejection_fraction=mean(abs(null)>critical+1e-12),
 gross_increment=gross_increment,expected_coupon_cost=coupon_cost,model_break_even_margin=threshold)
write.csv(s,'results/tables/summary.csv',row.names=FALSE)
fig<-function(name,draw){
 png(paste0('results/figures/',name,'.png'),width=1800,height=1100,res=170)
 par(mar=c(5.5,5.5,4,1.5),las=1,cex=.95,cex.main=1.05);draw();dev.off()
}
fig('01_bootstrap',function(){
 hist(boot,breaks=40,col='#D9E5EA',border='white',main='Does the coupon increase contribution profit?',xlab='Coupon minus control: dollars per assigned customer',ylab='Bootstrap resamples')
 abline(v=ci,col='#246B86',lty=2,lwd=2);abline(v=est,col='#BA4A32',lwd=2);abline(v=0,lty=3)
 legend('topright',c('Estimated profit difference','95% interval endpoints','Zero profit difference'),col=c('#BA4A32','#246B86','black'),lty=c(1,2,3),lwd=2,bty='n',cex=.8)
})
fig('02_coverage',function(){
 z<-coverage[1:100,];cols<-ifelse(z$covered,'#246B86','#BA4A32')
 plot(range(c(z$lower,z$upper,truth)),c(1,116),type='n',xlab='Profit difference: dollars per assigned customer',ylab='First 100 experiments in original order',main=sprintf('%.1f%% coverage in 2,000 simulated experiments',100*rate))
 abline(v=truth,lty=2,lwd=2);segments(z$lower,1:100,z$upper,1:100,col=cols)
 legend('topleft',c('Covers model truth','Misses model truth'),col=c('#246B86','#BA4A32'),lty=1,bty='n')
})
fig('03_null',function(){
 h<-hist(null,breaks=60,plot=FALSE)
 plot(h,col='#D9E5EA',border='white',main='Sampling variation when expected profits are equal',xlab='Profit difference: dollars per assigned customer',ylab='Null simulations',xlim=range(c(null,-abs(est),abs(est))))
 for(i in seq_along(h$counts)){
 a<-h$breaks[i];b<-h$breaks[i+1];y<-h$counts[i]
 if(b>critical) rect(max(a,critical),0,b,y,col='#F0C9BE',border=NA)
 if(a< -critical) rect(a,0,min(b,-critical),y,col='#F0C9BE',border=NA)
 if(b>abs(est)) rect(max(a,abs(est)),0,b,y,density=20,col='#BA4A32',border=NA)
 if(a< -abs(est)) rect(a,0,min(b,-abs(est)),y,density=20,col='#BA4A32',border=NA)
 }
 abline(v=c(-critical,critical),col='#246B86',lty=2,lwd=2)
 abline(v=c(-abs(est),abs(est)),col='#BA4A32',lwd=2)
 legend('topright',c('Approx. 5% rejection tails','Hatched: p-value tails'),fill=c('#F0C9BE',NA),density=c(NA,20),col=c(NA,'#BA4A32'),border=NA,bty='n',cex=.8)
})
# Embedded interaction, no auxiliary HTML file.
values<-paste(sprintf('{m:%.4f,e:%.8f,l:%.8f,u:%.8f}',sens$margin,sens$profit_difference,sens$lower,sens$upper),collapse=',')
widget<-paste0('<div style="padding:1rem;border:1px solid #cbd5e1"><label>Pre-coupon contribution margin: <select id="margin">',paste(sprintf('<option value="%d"%s>%.0f%%</option>',seq_along(margins)-1,ifelse(margins==margin,' selected',''),100*margins),collapse=''),'</select></label> <label>Campaign cost per recipient ($): <input id="cost" type="number" min="0" max="1" step="0.01" value="0" style="width:5rem"></label><p id="profit-result" aria-live="polite"></p><svg id="profit-chart" viewBox="0 0 640 120" style="width:100%" role="img" aria-label="Profit difference with 95 percent bootstrap interval"></svg><small>Purchase behavior stays fixed; costs and margins are scenarios, not estimated retailer costs.</small></div><script>(()=>{const rows=[',values,'];const m=document.getElementById("margin"),c=document.getElementById("cost"),t=document.getElementById("profit-result"),v=document.getElementById("profit-chart");function update(){const r=rows[+m.value],cost=Math.max(0,Number(c.value)||0),a=r.l-cost,b=r.u-cost,e=r.e-cost,lo=Math.min(0,a)-.02,hi=Math.max(0,b)+.02,x=z=>45+550*(z-lo)/(hi-lo);t.textContent="Estimated profit change: $"+e.toFixed(3)+" per customer; 95% interval: [$"+a.toFixed(3)+", $"+b.toFixed(3)+"]. "+(a>0?"Interval is above zero.":b<0?"Interval is below zero.":"Interval includes zero.");v.innerHTML=`<line x1="45" y1="75" x2="595" y2="75" stroke="#94a3b8"/><line x1="${x(0)}" x2="${x(0)}" y1="10" y2="80" stroke="#64748b" stroke-dasharray="4"/><line x1="${x(a)}" x2="${x(b)}" y1="40" y2="40" stroke="#246B86" stroke-width="5"/><circle cx="${x(e)}" cy="40" r="6" fill="#BA4A32"/>`+[lo,0,hi].map(z=>`<text x="${x(z)}" y="105" text-anchor="middle" font-size="13">$${z.toFixed(2)}</text>`).join("");}m.addEventListener("change",update);c.addEventListener("input",update);update();})();</script>')
# Numerical diagnostics; no extra report files.
stopifnot(all(abs(raw_sim$profit-c(x0,x1))<1e-12),
 abs(est-(mean(x1)-mean(x0)))<1e-12,
 max(abs(ci-quantile(boot,c(.025,.975))))<1e-12,
 abs(rate-.95)<4*sqrt(.95*.05/M)+.01,
 s$null_rejection_fraction<=.05001)
v0<-mean((x0-mean(x0))^2);v1<-mean((x1-mean(x1))^2)
se<-sqrt((v0+v1)/n)
stopifnot(abs(mean(null))<5*se/sqrt(H),abs(sd(null)/se-1)<.03)
invisible(s)
