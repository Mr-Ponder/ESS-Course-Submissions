function case_dir = week2_environment(work_dir)
% 任务四运行环境；从脚本所在目录向上查找课程资源，只修改当前会话路径。
case_dir = '';
parent = work_dir;
for level = 1:7
    candidates = {fullfile(parent,'ESS-Course-Materials-main','cases'), ...
        fullfile(parent,'ESS-Course-Materials','cases'),fullfile(parent,'cases')};
    for k = 1:numel(candidates)
        if isfile(fullfile(candidates{k},'profiles_24h.mat'))
            case_dir = candidates{k}; break;
        end
    end
    if ~isempty(case_dir), break; end
    parent = fileparts(parent);
end
if isempty(case_dir)
    source = which('case_chengshi_A');
    if ~isempty(source), case_dir = fileparts(source); end
end
assert(~isempty(case_dir),'请将教学资源库放在作业仓库旁，或将 cases 目录加入 MATLAB 路径。');
addpath(case_dir);
if exist('runpf','file') ~= 2
    roots = dir(fullfile(matlabroot,'toolbox','matpower*'));
    for k = 1:numel(roots)
        folder = fullfile(roots(k).folder,roots(k).name);
        if isfile(fullfile(folder,'install_matpower.m'))
            addpath(folder); install_matpower(1,0,0); break;
        end
    end
end
if exist('yalmip','file') ~= 2
    roots = {'D:/YALMIP-master',fullfile(matlabroot,'toolbox','YALMIP-master')};
    for k = 1:numel(roots)
        if isfolder(roots{k}), addpath(genpath(roots{k})); break; end
    end
end
addpath(fullfile(matlabroot,'toolbox','optim','optim'),'-begin');
assert(exist('runpf','file') == 2,'需要 MATPOWER。');
assert(exist('yalmip','file') == 2,'需要 YALMIP。');
assert(startsWith(which('intlinprog'),matlabroot,'IgnoreCase',true), ...
    '需要 MATLAB Optimization Toolbox 原生 intlinprog。');
end
