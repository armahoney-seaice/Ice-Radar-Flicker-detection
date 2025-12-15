function fflick = SIR_flicker_filter(flickimg, rad)

% Function called by SIR_flickerlyzer to filter a flicker image to:
% - remove 'speckle' of isolated flickering pixels;  and 
% - fill in 'holes' surrounded by lots of flickering neighbors

% USAGE:
%    fflick = SIR_flicker_filter(flickimg)
%    fflick = SIR_flicker_filter(flickimg, rad)
%
% INPUTS:
%    flickimg : binary image of flickering / non-flickering pixels
%         rad : pixel radius to use filter
%               default: 5
%
% OUTPUTS:
%      fflick : filtered binary flicker image
%
% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

% Set default value of 5 if filter radius isn't spec'd in function call
if ~exist('rad', 'var')
    rad = 5;
end


% Remove isolated flickering pixels by applying smoothing filter
% and excluding any pixels with a smoothed value < 0.25
% (i.e. any flicker pixel surrounded by fewer than 0.25*pi*rad^2 
%  other flicker pixels) 
diam = 2*rad + 1;
x = repmat(-rad:rad, diam, 1);
y = x';
r = sqrt(x.^2 + y.^2);
kern = (r <= rad);
kern = kern/sum(kern(:));
flickconv0 = conv2(flickimg, kern, 'same');
fflick0 = (flickimg > 0) .* (flickconv0 > 0.25);


% Close holes in flickering regions
% - First select all pixels within rad pixels of a flicker pixel
% - Then select only pixels (almost) entirely surrounded by 1s
flickconv1 = conv2(fflick0, kern, 'same');
fflick1 = (flickconv1 > 0);              
flickconv2 = conv2(fflick1, kern, 'same');
fflick = (flickconv2 > 0.9);

end