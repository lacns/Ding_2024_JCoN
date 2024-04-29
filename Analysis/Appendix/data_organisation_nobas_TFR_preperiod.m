function [cell_RSA] = data_organisation_nobas_TFR_pre(TFR,freqwin,channels,time_pro,time_ref,bas,split_band,subj)


TFR150 = TFR;
subj = erase(subj,'sub');
subj = str2num(subj);

% baseline - for trialinfo only
%[set_basl] = TFresult_chunking(TFR150,bas,bas,freqwin,split_band,channels);
%[set_basl] = baseline_comp(set_basl,time_pro,time_ref);

% add onset into trialinfo
trialinfo = TFR150.trialinfo;
% identify unfit pronouns (aka jou + overlaps)
jou = [77;593;684];
[C,It1,Ij] = intersect(trialinfo(:,1),jou); % It = indices of numbers in C
% unfit referents (with overlaps)
adj = [948;972;1017;1019;1207;797;930;928;802;864;999;799;904];
[C,It2,Ij] = intersect(trialinfo(:,1),adj); % It = indices of numbers in C

baseloc = '/project/3027010.01/';
Info = readtable([baseloc 'wordinfo_nounRef_new_v2.csv']);
for cnt = 1:height(trialinfo)
    wordcnt = trialinfo(cnt,1);
    ind_trl = find(Info.count == wordcnt);
    onset = Info.start(ind_trl);
    trialinfo(cnt,10) = onset;
end

%% ref-pro
% condition matrix
inx_pro = find(trialinfo(:,5)==1);
inx_ref = find(trialinfo(:,5)==2);

[C,It,Ij] = intersect(inx_ref,It2);
inx_ref(It) = [];
[C,It,Ij] = intersect(inx_pro,It1);
inx_pro(It) = [];

TFR150.inx_pro = inx_pro;
TFR150.inx_ref = inx_ref;
% same story or not
refstory = repmat(trialinfo(:,3),[1 length(trialinfo(:,3))]);
samestory = (refstory == refstory');
% same part or not
part = repmat(trialinfo(:,4),[1 length(trialinfo(:,4))]);
samepart = samestory & (part == part');
% same reference or not
refcode = repmat(trialinfo(:,2),[1 length(trialinfo(:,2))]);
sameitMat = (refcode == refcode');
sameitMat = double(sameitMat);
sameitMat(logical(eye(size(sameitMat)))) = -1;
sameitMat(samestory==0) = -1;
%% timing
onset = repmat(trialinfo(:,10),[1 length(trialinfo(:,10))]);
timing = onset - onset';
timing((timing>0) & (timing<2) & (samepart==1)) = 1;
sameitMat_following = zeros(size(timing));
wordcodes_trl = cell(size(timing,2),1);
for i=1:size(timing,2)
    % find immediately following words
    closewords_inx = find(timing(:,i)==1);
    % find their wordcodes
    closewords_code = refcode(closewords_inx,1); % shape
    onset_code = refcode(i,1);
    for j=1:(i-1)
        wordcodes_strl = wordcodes_trl{j,1};
        
        % check if any code of the current trl i matches that of preceding
        % trl j
        C1 = intersect(wordcodes_strl,closewords_code);
        % check if the onset of the current trl i matches codes of
        % following words of trl j
        len_wordcodes = length(wordcodes_strl);
        C2 = intersect(wordcodes_strl(2:len_wordcodes),onset_code);
        if (isempty(C1) == 0) || (isempty(C2) == 0)
            sameitMat_following(j,i) = 1;
            %disp(closewords_code);
        end
    end
    % add code of onset word into wordcodes of current trial
    closewords_code = [onset_code;closewords_code];
    % save the wordcodes in each trial for searching matching
    % following-words
    wordcodes_trl{i,1} = closewords_code;
end
sameitMat_following = sameitMat_following | sameitMat_following';
%% trial definition
% distance
reforder = repmat(trialinfo(:,7),[1 length(trialinfo(:,7))]);
dist = abs(reforder - reforder');
%dist = dist(inx_pro,inx_ref);

threshold = 1570;
dist(dist >= threshold) = -1;

trl_diff = (samestory==1) & (sameitMat==0) & (sameitMat_following~=1) & (dist~=-1);
trl_same = (samestory==1) & (sameitMat==1) & (sameitMat_following~=1);
trlinx_diff = trl_diff(inx_pro,inx_ref);
trlinx_same = trl_same(inx_pro,inx_ref);
%% data
cell_RSA = cell(50,50,1);
for j=1:1:(1/0.05) % pronoun sliding
    slidwin_pro = [-1 -0.95] + (j-1)*0.05; % 20231113: simply do pre period
    disp(j);
    for k=1:1:(1.35/0.05)
        slidwin_ref = [0 0.05] + (k-1)*0.05;
        set_data = TFresult_chunking(TFR150,slidwin_pro,slidwin_ref,freqwin,split_band,channels);
        disp(k);
        
        for l=1:size(set_data.results,2) % length = num of freq
            % baseline correction
            %basl_pro = set_basl.results{1,l};
            %basl_ref = set_basl.results{2,l};
            data_pro = set_data.results{1,l};
            data_ref = set_data.results{2,l};
            %data_pro = data_pro - basl_pro;
            %data_ref = data_ref - basl_ref;
            % RSA
            CorMat = corr(data_pro, data_ref, 'type', 'Spearman');
            % transform the data into columns (value, condition, participant)
            dp_same = mean(CorMat(trlinx_same)); % 20210728: only mean is taken into the next level
            dp_same(:,2) = 1; % condition
            dp_same(:,3) = subj; % participant id
            dp_diff = mean(CorMat(trlinx_diff));
            dp_diff(:,2) = 0; % condition
            dp_diff(:,3) = subj; % participant id
            dbl = [dp_same;dp_diff];
            % save the result
            dbl_org = cell_RSA{j,k,l};
            cell_RSA{j,k,l} = [dbl_org;dbl];
            %disp([j,k,l]);
        end
    end
end

end

