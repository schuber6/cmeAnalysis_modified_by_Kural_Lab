clear all;
path='FlyP2fxycMHZ_NEW.mat';
movie='FlyStack2TAv.tif';
frames=length(imfinfo(movie));
load(path);
load('FlyBigSpots.mat');
OfInterest=find(Selected);
h=waitbar(0,'Classifying Spots');
zs=zeros(1,length(OfInterest)*10);
iz=1;
Hs=zeros(1,length(OfInterest)*10);
iH=1;
selected2=[];
ints=zeros(1,length(OfInterest)*10);
ii=1;
for i=1:length(OfInterest)
    waitbar(i/length(OfInterest))
    used=find(fxyc(:,10,OfInterest(i)));
    for i2=1:length(used)
        z=fxyc(used(i2),10,OfInterest(i)); 
        zs(iz)=z;
        HWHM=fxyc(used(i2),9,OfInterest(i));
        if HWHM>0 && HWHM<=3
        Hs(iH)=HWHM;
        iH=iH+1;
        end
        int=fxyc(used(i2),8,OfInterest(i));
        ints(ii)=int;
        iz=iz+1;
        
        ii=ii+1;
    end
end
ZT=prctile(nonzeros(zs),50);
IT=prctile(nonzeros(ints),82);
HT=prctile(nonzeros(Hs),50);
for i=1:length(OfInterest)
    waitbar(i/length(OfInterest));
    zs=[];
    ints=[];
    Hs=[];
    used=find(fxyc(:,10,OfInterest(i)));
    for i2=1:length(used)
        z=fxyc(used(i2),10,OfInterest(i));
        HWHM=fxyc(used(i2),9,OfInterest(i));
        int=fxyc(used(i2),8,OfInterest(i));
        zs=[zs z];
        if HWHM>0 && HWHM<=3
        Hs=[Hs HWHM];
        end
        ints=[ints int];
    end
    if mean(Hs)>=HT && mean(ints)>=IT %&& I2(found(i2),i)>=BigThresh
        selected2=[selected2 OfInterest(i)];
    end
    %imwrite(B2,NewMovie2,'Writemode','append','Compression','none');
    waitbar(i/frames);
end
save FlyBigSpotsCalT-Z_NEW.mat selected2
PlotBigSpotsF(selected2,'FlySelectedCalT-Z.tif');
close(h);