function cramp=generatecolorramp(coldefs, Ncols)
% A program to generate custom color tables from a list of color
% definitions.
%
% USAGE
%   cramp=generatecolorramp(coldefs, Ncols)
%
% INPUTS
%    coldefs : A cell array containing two or more color definitions.
%              See below for more info on accepted values
%      Ncols : An integer specifying number of colors in output color ramp
%
% OUTPUT:
%      cramp : An Ncol-by-3 array of RGB color values (triplets)
%
% NOTES:
%    Color definitions may be either:
%         - a 3-5 character string; or 
%         - an RGB
%    Acceptable strings are of the form [m2][m1]ccc, where:
%    - ccc is a 3-character code identifying a pre-defined color
%    - m1 is a single character specifying a color modification:
%        "l" for light", "d" for dark
%    - m2 is simply the character "v" and specifies "very" when
%        applying a light or dark color modification
%
%
%    Predefined colors include:
%    - 'bla' : Black, rgb = [0,0,0]
%    - 'whi' : White, rgb = [1,1,1];
%    - 'red' : Red, rgb = [1,0,0];
%    - 'gre' : Green, rgb = [0,1,0];
%    - 'blu' : Blue, rgb = [0,0,1];
%    - 'yel' : Yellow, rgb = [1,1,0];
%    - 'cya' : Cyan, rgb = [0,1,1];
%    - 'mag' : Magenta, rgb = [1,0,1];
%    - 'ora' : Orange, rgb [1.0,0.75,0.0];
%    - 'gra' : Grey, rgb = [0.5,0.5,0.5];
%
%   Color variants can be either:
%   -   'l'  : Light (lighten RGB values by 33%, )
%   -   'd'  : Dark  (darken RGB values 25%)
%
%   If 'v' is specified the lightening or darkening is applied twice
%
%
% Andy Mahoney October 2023
%
% ------------------------------------------------------------------------


% Count number of color definitions specified in function call
Ncd = numel(coldefs);


% Assign specified rgb values to each definition
% (see str2rgb function below)
specrgbs = zeros(Ncd,3);
for c=1:Ncd
    if ischar(coldefs{c})
        specrgbs(c,:) = str2rgb(coldefs{c});
    elseif numel(coldefs{c}) == 3
        specrgbs(c,:) = coldefs{c};
    else
        disp('Bad color definition:');
        disp(coldefs{c});
        return
    end
end

% Define indices for output color ramp
ramp_i = 1:Ncols;

% Spread out specified colors evenly through color ramp 
spec_i = 1 + (0:Ncd-1)*(Ncols-1)/(Ncd-1);


% Generate colorramp through linear interpolation of RGB values
cramp = zeros(Ncols,3);
cramp(:,1) = interp1(spec_i, specrgbs(:,1), ramp_i);
cramp(:,2) = interp1(spec_i, specrgbs(:,2), ramp_i);
cramp(:,3) = interp1(spec_i, specrgbs(:,3), ramp_i);

end




function rgb = str2rgb(str)
% Sub-function of generatecolorramp to convert 
% a string-based color defintion into an RGB triplet

% Get length of input string
strlen = size(str,2);

% Crop to first 5 characters if string is any longer
if strlen > 5, str = str(1:5); end

% Check for color modifiers 
if strlen == 5
    vmod = str(1);
    mod = str(2);
    str = str(3:5);
elseif strlen == 4
    mod = str(1);
    str = str(2:4);
end

% Convert known color strings into rgb values
switch str
    case 'bla', rgb = [0,0,0];
    case 'whi', rgb = [1,1,1];
    case 'red', rgb = [1,0,0];
    case 'gre', rgb = [0,1,0];
    case 'blu', rgb = [0,0,1];
    case 'yel', rgb = [1,1,0];
    case 'cya', rgb = [0,1,1];
    case 'mag', rgb = [1,0,1];
    case 'ora', rgb = [1.0,0.75,0.0];
    case 'gra', rgb = [0.5,0.5,0.5];
    otherwise
        disp(['Unrecognized color code: ',str,'. Using white ...']);
        rgb = [1,1,1];
end

% Apply darkening or lightening color modification if specified
if exist('mod', 'var')
    switch mod
        case 'd'
           rgb = rgb*0.75;
        case 'l'
            rgb = rgb + 0.33*(1-rgb);
    end
end

% Re-apply darkening or lightening color modification if "v" is spec'd
if exist('vmod', 'var')
    switch mod
        case 'd'
           rgb = rgb*0.75;
        case 'l'
           rgb = rgb + 0.33*(1-rgb);
    end
end




end
