function LongMoviePostCME
wd=pwd;
smd = fullfile(wd,'split_movies');
omd = fullfile(wd,'orig_movies');

tmpd = dir(fullfile(omd,'*.tif'));
orig_movies = cell(length(tmpd),1);
for i = 1:length(tmpd)
orig_movies{i} = fullfile(omd,tmpd(i).name);
end

folderlist = dir(smd);
load_thresh = logical(exist(fullfile(smd,'threshs.mat'),'file'));

dirname = cell(length(folderlist)-2-load_thresh,1);
for i = 1:length(dirname)
    dirname{i} = fullfile(smd,folderlist(i+2).name);
end
movies = length(dirname);
SectionSize = zeros(movies,1);
Threshs = cell(movies,1);
sections = -2*ones(movies,1);
for i = 1:movies
    folderlist2 = dir(dirname{i});
    for j = 1:length(folderlist2)
        if folderlist2(i).isdir
            sections(i) = sections(i)+1;
        end
    end
end
moviefol = cell(max(sections),movies);
moviename = cell(max(sections),movies);
paths = cell(max(sections),movies);
for i = 1:movies
    tpath = cell(length(sections(i)),1);
    tname = cell(length(sections(i)),1);
    for i2 = 1:sections(i)
        tmpn = fullfile(dirname{i},['Section',num2str(i2)]);
        tmpd = dir(tmpn);
        moviefol{i2,i} = fullfile(tmpn,tmpd(3).name,'ch1');
        paths{i2,i} = fullfile(moviefol{i2,i},'Tracking','ProcessedTracks.mat');
        tmpn = dir(fullfile(moviefol{i2,i},'*.tif'));
        moviename{i2,i} = tmpn.name;
        if i2==1
            SectionSize(i) = length(imfinfo(moviename{i2,i}));
        end
        tpath{i2} = paths{i2,i};
        tname{i2} = moviename{i2,i};
    end
    
    if ~load_thresh
        [Threshs{i}]=LongMovieThreshholdSelection(tpath,tname,SectionSize(i));
    end
    
end
if load_thresh
    load(fullfile(smd,'threshs.mat'));
else
    save(fullfile(smd,'threshs.mat'));
end

for i9=1:movies
    Thresh=Threshs{i9};
    %     MultiSectionSuperTrackWrapper_auto
    for i = 1:sections(i9)
        if ~exist(fullfile(fileparts(paths{i,i9}),'TempTraces.mat'),'file')
            SimplifiedTrackWrapperNewEndDetection(paths{i,i9},Thresh,moviename{i,i9}, 4,1,0,.75);
        end
    end
    array=cell(sections(i9),1);
    SizeArray=zeros(sections(i9),3);
    start = zeros(sections(i9),1);
    for i = 1:sections(i9) %Access all the TempTraces files and make the Threshfxyc's into a stucture array
        load(fullfile(fileparts(paths{i,i9}),'TempTraces.mat'))
        if i==1
            start(i)=1;
        else
            start(i)=(i-1)*SectionSize(i9); %Make a frame of overlap so that the traces in different sections can be put together
        end
        array{i}=Threshfxyc;
        SizeArray(i,:)=size(Threshfxyc);
    end
    %save('IndividualThreshs.mat','-v7.3');
    Threshfxyc=zeros(max(SizeArray(:,1)),max(SizeArray(:,2)),sum(SizeArray(:,3)));%Initialize Threshfxyc with appropriate array size
    index=1; %Keeps track of first open slot in Threshfxyc(~,~,:)
    h=waitbar(0,'Compiling Trace Sections');
    maxfree=10;
    if sections(i9)>1
        for i=1:sections(i9)-1 %Go through all adjacent pairs of sections looking for corresponding trace ends
            waitbar(i/(sections(i9)-1))
            fxyc1=array{i}; %Check structure syntax
            fxyc2=array{i+1};
            [A1,A2,A3]=size(fxyc1);
            [~,~,B3]=size(fxyc2);
            if i==1
                routingnew=zeros(A3,1);
            end
            for i2=1:A3
                used=find(fxyc1(:,1,i2));
                for i3=1:length(used)
                    fxyc1(used(i3),1,i2)=fxyc1(used(i3),1,i2)+start(i)-1;
                end
                if i==1 %i==1 is special because it is never in fxyc2, so it must be saved now
                    for i3=1:A1
                        for i4=1:A2
                            Threshfxyc(i3,i4,index)=fxyc1(i3,i4,i2);
                        end
                    end
                    routingnew(i2)=index; %Keeps track of where entries in this fxyc go so that corresponding entries in next one go to the right place
                    index=index+1;
                end
            end
            routingold=routingnew;
            routingnew=zeros(B3,1); %Make room so routing numbers from this section can be recorded while keeping the ones from the last section
            for i2=1:B3
                used=find(fxyc2(:,1,i2));
                for i3=1:length(used)
                    fxyc2(used(i3),1,i2)=fxyc2(used(i3),1,i2)+start(i+1)-1; %Change section frame numbers to full movie frame numbers
                end
                firstframe=find(fxyc2(:,1,i2)==start(i+1)); %Look for pits in the first frame
                found=0;
                if ~isempty(firstframe)
                    for i3=1:A3 %Look for corresponding pits in the last frame of the previous section
                        found1=find(fxyc1(:,1,i3)==start(i+1));
                        found2=find(fxyc1(:,2,i3)==fxyc2(firstframe(1),2,i2));
                        found3=find(fxyc1(:,3,i3)==fxyc2(firstframe(1),3,i2));
                        f=intersect(found1,intersect(found2,found3));
                        if ~isempty(f)
                            found=i3;
                            break
                        end
                    end
                end
                if found==0 %No corresponding pit was found
                    for i3=1:length(used)
                        for i4=1:A2
                            Threshfxyc(i3,i4,index)=fxyc2(used(i3),i4,i2);
                            
                        end
                    end
                    routingnew(i2)=index;
                    index=index+1;
                else %corresponding pit was found
                    free=find(Threshfxyc(:,1,routingold(found))==0,1,'first'); %Where new trace data can be put
                    if isempty(free)
                        [C1,~,~]=size(Threshfxyc);
                        free=C1+1;
                    end
                    for i3=2:length(used)
                        for i4=1:A2
                            Threshfxyc(free(1),i4,routingold(found))=fxyc2(used(i3),i4,i2);
                            
                        end
                        free(1)=free(1)+1;
                        %                 if free(1)>300  %Cut off super long traces--this was put in as a simple fix to a memory error--if problems occur, this should be revisited
                        %                     break
                        %                 end
                    end
                    if free(1)>maxfree
                        maxfree=free(1);
                        disp(maxfree);   %Display max dimension to check why a certain error happened
                    end
                    routingnew(i2)=routingold(found);
                    
                end
                
            end
        end
    else
        Threshfxyc=array{1};
    end
    close(h)

    
%     save([pwd,'/tempdata.mat'], 'Threshfxyc', 'Thresh', 'movie', 'wd', 'wdW','-v7.3')
%     clear all
%     load([pwd,'/tempdata.mat'])
    TraceFinalizationWOConnector(Threshfxyc,Thresh,orig_movies{i9},4,1,0,.75);
    %save TempTraces.mat Threshfxyc
    %end
end
end