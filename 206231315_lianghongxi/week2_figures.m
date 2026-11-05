function figs=week2_figures(folder,D,S)
colors=[0 0.4470 0.7410;0.8500 0.3250 0.0980;0.4660 0.6740 0.1880];
hours=1:24; installed=find(D.Z==1);

figs.Voltage=figure('Color','w','Position',[120 90 900 680],'Name','任务四：规划前后电压与线性误差');
tiledlayout(2,1,'TileSpacing','compact','Padding','compact');
ax=nexttile; hold(ax,'on');
plot(hours,D.VacBase(D.WorstBus,:),'--k','LineWidth',2);
plot(hours,D.Vlin(D.WorstBus,:),'-s','Color',colors(1,:),'LineWidth',2,'MarkerSize',5);
plot(hours,D.Vac(D.WorstBus,:),'-o','Color',colors(2,:),'LineWidth',2,'MarkerSize',5);
style(ax); ylabel('电压 / p.u.','FontName','SimSun'); xlabel('时间 / h','FontName','SimSun');
title(sprintf('(a) 基准薄弱节点 %d 的24小时电压',D.WorstBus),'FontName','SimSun','FontWeight','normal');
legend({'无储能交流潮流','配置后线性模型','配置后交流潮流'},'FontName','SimSun','Location','northoutside','Orientation','horizontal');
xlim([1 24]); xticks(1:3:24);
ax=nexttile; plot(hours,max(abs(D.Vlin-D.Vac),[],1),'-o','Color',colors(1,:),'LineWidth',2,'MarkerSize',5);
style(ax); xlim([1 24]); xticks(1:3:24);
ylabel('全网最大电压偏差 / p.u.','FontName','SimSun'); xlabel('时间 / h','FontName','SimSun');
title(sprintf('(b) 线性模型与交流潮流偏差；全网最大值 %.3g p.u.',D.MaxVoltageError),'FontName','SimSun','FontWeight','normal');
export(figs.Voltage,folder,sprintf('Fig_Week2_%d',D.StuID));
% 同一图形兼容通用README的Planning名称与第二周补充通知的简写名称。
for ext={'.png','.pdf','.fig'}
    copyfile(fullfile(folder,sprintf('Fig_Week2_%d%s',D.StuID,ext{1})),...
        fullfile(folder,sprintf('Fig_Week2_Planning_%d%s',D.StuID,ext{1})));
end

figs.Configuration=figure('Color','w','Position',[140 100 950 500],'Name','任务四：配置与年费用');
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
ax=nexttile; bar(1:numel(D.CandidateBuses),[D.RatedPowerMW,D.RatedEnergyMWh],'grouped');
xticks(1:numel(D.CandidateBuses)); xticklabels(string(D.CandidateBuses));
style(ax); ylabel('配置值','FontName','SimSun'); xlabel('候选母线编号','FontName','SimSun');
legend({'额定功率 / MW','额定能量 / MWh'},'FontName','SimSun','Location','northoutside');
title('(a) 最优选址定容方案','FontName','SimSun','FontWeight','normal');
ylim([0,max(1,max(D.RatedEnergyMWh))*1.4]);
ax=nexttile; values=[D.Cost.InvestmentAnnual,D.Cost.MaintenanceAnnual,D.Cost.GridAnnual]/1e4;
bars=bar(categorical({'投资等年值','年运维','年购电'}, {'投资等年值','年运维','年购电'}),values,'FaceColor',colors(1,:)); %#ok<NASGU>
style(ax); set(ax,'FontName','SimSun'); ylabel('年费用 / 万元','FontName','SimSun');
title(sprintf('(b) 最优年综合费用 %.4f 万元',D.Cost.TotalAnnual/1e4),'FontName','SimSun','FontWeight','normal');
ylim([0,max(values)*1.18]);
for i=1:3, text(i,values(i)+max(values)*0.035,sprintf('%.4f',values(i)),...
        'HorizontalAlignment','center','FontName','Times New Roman','FontSize',11); end
export(figs.Configuration,folder,sprintf('Fig_Week2_Configuration_%d',D.StuID));

figs.Operation=figure('Color','w','Position',[160 80 900 850],'Name','任务四：储能运行计划');
tiledlayout(3,1,'TileSpacing','compact','Padding','compact');
ax=nexttile; stairs(hours,D.PriceMWh/1000,'Color',colors(1,:),'LineWidth',2);
style(ax); xlim([1 24]); ylabel('电价 / (元/kWh)','FontName','SimSun');
title('(a) 分时电价','FontName','SimSun','FontWeight','normal');
ax=nexttile; hold(ax,'on'); labels=cell(1,numel(installed));
for n=1:numel(installed)
    i=installed(n); stairs(hours,D.DischargeMW(i,:)-D.ChargeMW(i,:),...
        'Color',colors(i,:),'LineWidth',2); labels{n}=sprintf('节点%d',D.CandidateBuses(i));
end
if isempty(installed), plot(hours,zeros(1,24),'k-','LineWidth',2); labels={'未建设储能'}; end
style(ax); xlim([1 24]); ylabel('净放电功率 / MW','FontName','SimSun');
title('(b) 正值放电，负值充电','FontName','SimSun','FontWeight','normal');
legend(labels,'FontName','SimSun','Location','northoutside','Orientation','horizontal');
ax=nexttile; hold(ax,'on');
for n=1:numel(installed)
    i=installed(n); plot(0:24,[0.5,D.SoC(i,:)],'-o','Color',colors(i,:),'LineWidth',2,'MarkerSize',4);
end
if isempty(installed), text(12,0.5,'最优方案未建设储能，无实际SoC曲线','FontName','SimSun','HorizontalAlignment','center'); end
style(ax); xlim([0 24]); ylim([0.15 0.85]); xticks(0:4:24);
ylabel('荷电状态 SoC','FontName','SimSun'); xlabel('时间 / h','FontName','SimSun');
title('(c) 初始与日末SoC均为0.50','FontName','SimSun','FontWeight','normal');
export(figs.Operation,folder,sprintf('Fig_Week2_Dispatch_%d',D.StuID));

figs.Sensitivity=figure('Color','w','Position',[180 80 1000 720],'Name','任务四：参数灵敏度');
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
costRows=S(abs(S.VminLin-0.96)<1e-10,:); costRows=sortrows(costRows,'EnergyCostMultiplier');
voltageRows=S(abs(S.EnergyCostMultiplier-1)<1e-10,:); voltageRows=sortrows(voltageRows,'VminLin');
ax=nexttile; plot(costRows.EnergyCostMultiplier,costRows.TotalEnergy_MWh,'-o','Color',colors(1,:),'LineWidth',2);
style(ax); xlabel('单位能量投资成本倍率','FontName','SimSun'); ylabel('总容量 / MWh','FontName','SimSun');
title('(a) 投资费用对配置的影响','FontName','SimSun','FontWeight','normal');
ax=nexttile; plot(costRows.EnergyCostMultiplier,costRows.AnnualCost_Yuan/1e4,'-s','Color',colors(2,:),'LineWidth',2);
style(ax); xlabel('单位能量投资成本倍率','FontName','SimSun'); ylabel('年综合费用 / 万元','FontName','SimSun');
title('(b) 投资费用与最优年费用','FontName','SimSun','FontWeight','normal');
ax=nexttile; plot(voltageRows.VminLin,voltageRows.TotalEnergy_MWh,'-o','Color',colors(1,:),'LineWidth',2);
style(ax); xlabel('线性模型电压下限 / p.u.','FontName','SimSun'); ylabel('总容量 / MWh','FontName','SimSun');
title('(c) 电压约束对配置的影响','FontName','SimSun','FontWeight','normal');
ax=nexttile; plot(voltageRows.VminLin,voltageRows.MinACVoltage,'-s','Color',colors(2,:),'LineWidth',2);
style(ax); xlabel('线性模型电压下限 / p.u.','FontName','SimSun'); ylabel('交流最低电压 / p.u.','FontName','SimSun');
title('(d) 交流运行结果','FontName','SimSun','FontWeight','normal');
export(figs.Sensitivity,folder,sprintf('Fig_Week2_Sensitivity_%d',D.StuID));
end

function style(ax)
set(ax,'FontName','Times New Roman','FontSize',11,'LineWidth',1,'Box','on',...
    'Color','w','XColor','k','YColor','k','TickDir','in','GridAlpha',0.18);
grid(ax,'on');
end

function export(fig,folder,stem)
drawnow;
exportgraphics(fig,fullfile(folder,[stem '.png']),'Resolution',600,'BackgroundColor','white');
exportgraphics(fig,fullfile(folder,[stem '.pdf']),'ContentType','vector','BackgroundColor','white');
savefig(fig,fullfile(folder,[stem '.fig']));
end
