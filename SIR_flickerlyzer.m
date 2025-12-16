function SIR_flickerlyzer(sirlist, varargin)
% Function to detect "flickering" in a sequence of sea ice radar (SIR) imagery
% - calculates pixel normalized standard deviation, Qstdn
% - assigns flickering status if Qstdn > thresh (=1, by default)
% - non flickering pixels are considered "steady"
% Flicker image is output as color-coded images with split color map
% - brightness values are scaled in range 0-127
% - steady pixels are assigned a 128-color grayscale color map
% - flickering pixels  are assigned a 128-color cyanscale color map

% -----------------------------------------------------------------------
% USAGE:
% SIR_flickerlyzer(sirlist)
% SIR_flickerlyzer(__, 'Ns', Ns)
% SIR_flickerlyzer(__, 'outpathflick', outpathflick)
% SIR_flickerlyzer(__, 'outpathmean', outpathmean)
% SIR_flickerlyzer(__, 'thresh', thresh)
% SIR_flickerlyzer(__, 'filtrad', frad)
% SIR_flickerlyzer(__, 'owrite', overwrite)
% SIR_flickerlyzer(__, 'meanimgout', meanimgout)
% SIR_flickerlyzer(__, 'statsout', statsout)
%
% INPUTS:
%       sirlist : a (Nf x 1) cell array containing filenames of images 
%                to be analyzed
%           Ns : integer specifiying the sequence/queue length. That is, the 
%                number of consecutive images to be grouped when calculating
%                the pixel-wise standard deviation
%                Default: 3
% outpathflick : A string specifying the output path for the image file
%                created from each Ns-image sequence
%                Default: A folder called "FlickerImages_sddd"
%                         where ddd is a 3-digit number referring the 
%                         sequence length, Ns. This folder will be created, 
%                         if necesessary, in the deepest common folder 
%                         found from the input files
%  outpathmean : A string specifying the output path for the image file
%                created from each Ns-image sequence
%                Default: The same name used for outpathflick, but with 
%                         "Flick" or "Flicker" replaced with "StackMean".
%       thresh : A scalar value specifying the threshold value of the
%                normalized standard deviation for defining flickering
%                Default: 0.05
%      filtrad : A integer scalar value specifying a radius to use in an 
%                opening / closing filter to reduce flicker speckle
%                Default: 0 (no filter applied)
%     brighten : A scalar value corresponding to a linear brightening applied
%                to all pixels in resulting amplitude images. 
%                Values are clipped at upper end 
%                Default: 1.5 (50% brightening)
%        owrite: A binary flag (0 or 1) specifying whether or not to overwrite
%                existing flicker files if they already exists in output folder   
%    meanimgout : A binary flag (0 or 1) specifying whether or not to output
%                the mean stack image. If set to 1, the image file will be 
%                created in the output folder specified by outpathmean
%                Default: 0 (no output)
%     statsout : A binary flag (0 or 1) specifying whether or not to output
%                an additional Matlab data file containing the mean and 
%                standard deviation fields for each image queue. If set
%                set to 1, the data file will be created in the same output 
%                folder as the output flicker image
%                Default: 0 (no output)
%
% OUTPUT:
%    1. Ficker image:
%    Primary output of this function is a series of PNG files visualizing 
%    regions of an SIR image that exhibit flicker or movement.
%    Each flicker image file takes the name of the last file in the image 
%    sequence and adds the suffix "_flicker.png"
%    The number of files created will be equal to Nf - (Ns-1), where Nf 
%    is the number of files specified in sirlist and Ns is the sequence size
%    A comment is added to the exif information for the image that
%    specifies some of the key flickerlyzer parameters. 
%    The comment takes the form:
%       'Ns=%0.0f, Ncol=%0.0f, frad=%0.0f'
%
%    2. Stack mean image:
%    In the process of deriving the flicker image, this function also
%    calculates the pixel-wise mean image. This image is output as a PNG
%    file with the suffix "_Smean.png"
% 
%    3. If statsout is set to 1, then this function will also output a
%     Matlab data file with the suffix "_Qstats.mat" for each PNG output file.
%     This data file contains the following values:
%          -  imgQ : an m-by-n-by-Ns array representing the queue of images
%                    used to derive each flicker image
%          -  Qstd : Pixel-wise standard deviation of the image queue
%          - Qmean : Pixel-wise mean value of the image queue
%          - Qstdn : Standard dev normalized by mean
%
%
% Andy Mahoney
% ** Nov 2025: Updates for implementation on the local OnLogic attached to
%              each sea ice radar. 
%  - Applied sqrt to pixel-wise mean before normalizing by stdev
%    This effectively lowers the stdev required for bright pixels to be
%    counted as flickering. 
%    This also requires adjustment of flickering threshold. 
%    A value near 1 seems to work well
%  - Added a morphology operation (imclearborder) to treat regions of 
%    non-flickering pixels as flickering if they are completely enclosed
%    by flickering pixels
%  - Applied consistent brightening to both flickering and non-flickering
%    pixels. Flickering pixels were previously brightened by a factor of 2
%    Default value is now to brigthen pixels by 1.5 and then clip.
%  - Added output of pixel-wise "Fmean" image.
% ===========================================================================



% -------------------------------------------------------
% Handle any optional arguments passed with function call
a = 1;
while a <= numel(varargin)
    switch varargin{a}
        case 'Ns'
            Ns = varargin{a+1};
            a = a + 2;
        case 'outpathflick'
            outpathflick = varargin{a+1};
            a = a + 2;
        case 'outpathmean'
            outpathmean = varargin{a+1};
            a = a + 2;
        case 'thresh'
            thresh = varargin{a+1};
            a = a + 2;
        case 'filtrad'
            frad = varargin{a+1};
            a = a + 2;
        case 'brighten'
            brighten = varargin{a+1};
            a = a + 2;
        case 'owrite'
            owrite = varargin{a+1};
            a = a + 2;
        case 'meanimgout'
            meanimgout = varargin{a+1};
            a = a + 2;
        case 'statsout'
            statsout = varargin{a+1};
            a = a + 2;
        otherwise
            disp('Argument not recognized:')
            disp(varargin{a});
            a = a + 1;
    end
end


% --------------------------------------------------------------
% Set default values for arguments not passed with function call

% Set sequence length if not specified in function call
if ~exist('Ns', 'var')
    Ns = 3;
end
Ns_str = num2str(Ns, '%03d');

% Set output folder for flicker images if not specified in function call
if ~exist('outpathflick', 'var')
    outpathflick = [deepcommpath(sirlist) filesep 'FlickerImages_' Ns_str];
end

% Create output folder if necessary
if ~exist(outpathflick, 'file')
    mkdir(outpathflick);
end

% Set output folder for mean images if not specified in function call
if ~exist('outpathmean', 'var')
    outpathmean = regexprep(outpathflick, 'Flick(er)*', 'StackMean');
end

% Set meanimgout flag if not specified in function call
if ~exist('meanimgout', 'var')
    meanimgout = 0;
end

% Create output folder if necessary
if ~exist(outpathmean, 'file') && (meanimgout == 1)
    mkdir(outpathmean);
end

% Set threshhold for change detection if not specified in function call
if ~exist('thresh', 'var')
    thresh = 0.05;
end

% Set filter radius to zero if not specified in function call
if ~exist('frad', 'var')
    frad = 0;
end

% Set brigthening factor to 1.5 if not specified in function call
if ~exist('brighten', 'var')
    brighten = 1.5;
end


% Set overwrite flag to zero if not specified in function call
if ~exist('owrite', 'var')
    owrite = 0;
end

% Set statsout flag if not specified in function call
if ~exist('statsout', 'var')
    statsout = 0;
end

% --------------------------------------------
% Count number of files in input filename list
Nsir = numel(sirlist);

% Define color ramps for different parts of image
% - By setting Ncol to 128, we can divide the 8-bit range into two halves
% - the top half used for a grayscale color ramp for non-moving pixels
% - the top half is used for a cyanscale color ramp for flickering/moving
%   pixels
Ncol = 128;
cmap_nomove = generatecolorramp({'bla','whi'}, Ncol);
cmap_flicker = generatecolorramp({'bla','cya'}, Ncol);
cmap_out = [cmap_nomove; cmap_flicker];


% --------------------------------------------
% Populate inital image queue:
%  - first-in-first-out queue of images
%  - with last image left empty
img = imread(sirlist{1});
if ndims(img) > 2
    img = mean(img, 3);  % Convert to grayscale if file contains RGB image
end
sz = size(img);
imgQ = zeros(sz(1),sz(2),Ns);
imgQ(:,:,Ns-1) = img;
for s=2:Ns-1
    [img, map] = imread(sirlist{s});
    if numel(map) > 0
        mapmean = mean(map, 2);    % Convert to grayscale if file contains
        img = 255*mapmean(img+1);  % color map (i.e. color indexed image)
    end
    if ndims(img) > 2
        img = mean(img, 3); % Convert to grayscale if file contains RGB image
    end
    imgQ(:,:,Ns-s) = img;
end


% ---------------------------------------------------------------------
% Go through remaining images in input list and generate flicker images

% Regular expression for pulling date string out of filename
drexp = '20[0-9][0-9][0-1][0-9][0-3][0-9]';

for s=(Ns-1):Nsir
    
    % Shift queue down and add new image at top
    imgQ(:,:,2:Ns) = imgQ(:,:,1:Ns-1);
    [img, map] = imread(sirlist{s});
    if numel(map) > 0
        mapmean = mean(map, 2);    % Convert to grayscale if file contains
        img = 255*mapmean(img+1);  % color map (i.e. color indexed image)
    end
    if ndims(img) > 2
        img = mean(img, 3); % Convert to grayscale if file contains RGB image
    end
    imgQ(:,:,1) = img;
    
    % Take most recent filename in queue for output name
    [~,outstem,~] = fileparts(sirlist{s});
    outflickfile = [outstem '_flick.png'];
    outmeanfile = [outstem '_Smean.png'];

    % Create year/month/day filestructure for output files if necessary
    yyyymmdd = regexp(outstem, drexp, 'match');
    yyyymmdd = yyyymmdd{1};
    yyyy = yyyymmdd(1:4);
    outdirflick = [outpathflick filesep yyyy filesep yyyymmdd];
    outdirmean = [outpathmean filesep yyyy filesep yyyymmdd];
    if ~exist(outdirflick, 'file')
        mkdir(outdirflick);
    end
    if ~exist(outdirmean, 'file')
        mkdir(outdirmean);
    end
    
    % Skip to next file if flicker image already exists
    % and overwrite flag is set to zero
    if (owrite == 0) && exist([outdirflick filesep outflickfile], 'file')
        %disp(['Already exists: ' outfile]);
        continue;
    end

    % Calculate stats required to determine flickering
    Qstd = std(imgQ, 0, 3);     % Pixel-wise standard deviation
    Qmean = mean(imgQ, 3);      % Pixel-wise mean value
    Qstdn = Qstd./sqrt(Qmean);  % Standard dev normalized by sqrt of mean
    
    % Segment image by thresholds into two categories
    nomove = (Qstdn < thresh);
    flicker = (Qstdn >= thresh);
       
    % Apply opening/closing filter if specified in function call
    if frad > 0
        flicker = SIR_flicker_filter(flicker, frad);
        nomove = ~flicker;
    end

    % Now fill-in any non-flickering pixels that are completely
    % enclosed by flickering pixels
    nomove_enc = imclearborder(nomove, 8);
    flicker = flicker | nomove_enc;
    nomove = nomove & ~nomove_enc;

    % Scale pixel values within each segment in range 0 to Ncol-1
    % - brighten and clip values to Ncol -1
    scale = brighten*(Ncol-1)/255;
    nomove_img = scale*imgQ(:,:,Ns).*nomove;
    if any(flicker(:))
        flicker_img = scale*imgQ(:,:,Ns).*flicker;
    end
    
    % Truncate excessive values
    nomove_img(nomove_img > Ncol-1) = Ncol-1;
    flicker_img(flicker_img > Ncol-1) = Ncol-1;
    

    % Construct output image combining flickering and non-flickering pixels
    % - Recall Ncol is set to 128 so we have split our 8-bit color map into
    %   two 7-bit color ramps
    % - We therefore rescale the original 0-255 values to the range 0-127
    %   and add 128 to all flickering pixels
    % - This way, non-flickering pixels use the lower color ramp
    %   and flickering pixels use the upper ramp
    outimg = nomove_img + flicker*Ncol + flicker_img;    
    outimg = uint8(outimg);
    

    % Write flicker image to PNG file with comment string
    % providing the sequence length and 
    % number of colors in each color ramp
    commstr = sprintf('Ns=%0.0f, Ncol=%0.0f, frad=%0.0f', Ns, Ncol, frad);
    imwrite(outimg, cmap_out, [outdirflick filesep outflickfile], ...
            'comment', commstr);
    disp(['Written: ' outflickfile]);


    % Write flicker mean image to PNG file with comment string
    % providing the sequence length and 
    % number of colors in each color ramp
    if meanimgout > 0
        commstr = sprintf('Ns=%0.0f', Ns);
        imwrite(uint8(Qmean), [outdirmean filesep outmeanfile], ...
                'comment', commstr);
        disp(['Written: ' outmeanfile]);
    end

    % Write the underlying stats to a data file if specified in function
    % call. This is primarily for diagnostics
    if statsout > 0
        statsfile = [outstem '_Qstats.mat'];
        save([outdirflick filesep statsfile], 'imgQ', ...
                                         'Qstd', ...
                                         'Qmean', ...
                                         'Qstdn');
    end
    notalot = 0;
end

end
    
    