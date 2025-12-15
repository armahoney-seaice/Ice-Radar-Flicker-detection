function SIR_flickerlyzer_old(sirlist, varargin)
% Function to detect "flickering" in sea ice radar (SIR) imagery
% through simple calculation of pixel-wise standard deviation
% from a sequence of images

% USAGE:
% SIR_flickerlyzer(sirlist)
% SIR_flickerlyzer(__, 'Ns', Ns)
% SIR_flickerlyzer(__, 'outpath', outpath)
% SIR_flickerlyzer(__, 'thresh', thresh)
% SIR_flickerlyzer(__, 'filtrad', frad)
% SIR_flickerlyzer(__, 'owrite', overwrite)
% SIR_flickerlyzer(__, 'statsout', statsout)
%
% INPUTS:
%  sirlist : a (Nf x 1) cell array containing filenames of images 
%            to be analyzed
%       Ns : integer specifiying the sequence/queue length. That is, the 
%            number of consecutive images to be grouped when calculating
%            the pixel-wise standard deviation
%            Default: 3
%  outpath : A string specifying the output path for the image file
%            created from each Ns-image sequence
%            Default: A folder called "FlickerImages_sddd", where ddd is
%                     a 3-digit number referring the sequence length, Ns
%                     This folder will be created, if necesessary, in the
%                     deepest common folder found from the input files
%   thresh : A scalar value specifying the threshold value of the
%            normalized standard deviation for defining flickering
%            Default: 0.05
%  filtrad : A integer scalar value specifying a radius to use in an 
%            opening / closing filter to reduce flicker speckle
%            Default: 0 (no filter applied)
%    owrite: A binary flag (0 or 1) specifying whether or not to overwrite
%            existing flicker files if they already exists in output folder   
% statsout : A binary flag (0 or 1) specifying whether or not to output
%            an additional Matlab data file containing the mean and 
%            standard deviation fields for each image queue. If set
%            set to 1, the data file will be created in the same output 
%            folder as the output flicker image
%            Default: 0 (no output)
%
% OUTPUT:
%    This function writes PNG files visualizing regions of an SIR image
%    that exhibit flicker or movement. Each output file takes the name
%    of the last file in the image sequence with the suffix "_flicker.png"
%    The number of files created will be equal to Nf - (Ns-1), where Nf 
%    is the number of files specified in sirlist and Ns is the sequence size
%    A comment is added to the exif information for the image that
%    specifies some of the key flickerlyzer parameters. 
%    The comment takes the form:
%       'Ns=%0.0f, Ncol=%0.0f, frad=%0.0f'
%
%     If statsout is set to 1, then this function will also output a
%     Matlab data file with the suffix "_Qstats.mat" for each PNG output file.
%     This data file contains the following values:
%          -  imgQ : an m-by-n-by-Ns array representing the queue of images
%                    used to derive each flicker image
%          -  Qstd : Pixel-wise standard deviation of the image queue
%          - Qmean : Pixel-wise mean value of the image queue
%          - Qstdn : Standard dev normalized by mean
% ===========================================================================



% -------------------------------------------------------
% Handle any optional arguments passed with function call
a = 1;
while a <= numel(varargin)
    switch varargin{a}
        case 'Ns'
            Ns = varargin{a+1};
            a = a + 2;
        case 'outpath'
            outpath = varargin{a+1};
            a = a + 2;
        case 'thresh'
            thresh = varargin{a+1};
            a = a + 2;
        case 'filtrad'
            frad = varargin{a+1};
            a = a + 2;
        case 'owrite'
            owrite = varargin{a+1};
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

% Set output folder if not specified in function call
if ~exist('outpath', 'var')
    outpath = [deepcommpath(sirlist) filesep 'FlickerImages_' Ns_str];
end

% Create output folder if necessary
if ~exist(outpath, 'file')
    mkdir(outpath);
end

% Set threshhold for change detection if not specified in function call
if ~exist('thresh', 'var')
    thresh = 0.05;
end

% Set filter radius to zero if not specified in function call
if ~exist('frad', 'var')
    frad = 0;
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
    outfile = [outstem '_flick.png'];

    % Create year/month/day filestructure for output files if necessary
    yyyymmdd = regexp(outstem, drexp, 'match');
    yyyymmdd = yyyymmdd{1};
    yyyy = yyyymmdd(1:4);
    outdir = [outpath filesep yyyy filesep yyyymmdd];
    if ~exist(outdir, 'file')
        mkdir(outdir);
    end
    
    % Skip to next file if flicker image already exists
    % and overwrite flag is set to zero
    if (owrite == 0) && exist([outdir filesep outfile], 'file')
        %disp(['Already exists: ' outfile]);
        continue;
    end

    % Calculate stats required to determine flickering
    Qstd = std(imgQ, 0, 3);     % Pixel-wise standard deviation
    Qmean = mean(imgQ, 3);      % Pixel-wise mean value
    Qstdn = Qstd./Qmean;        % Standard dev normalized by mean
    
    % Segment image by thresholds into two categories
    nomove = (Qstdn < thresh);
    flicker = (Qstdn >= thresh);
       
    % Apply opening/closing filter if specified in function call
    if frad > 0
        flicker = SIR_flicker_filter(flicker, frad);
        nomove = ~flicker;
    end

    % Scale pixel values within each segment
    nomove_img = Ncol/255*imgQ(:,:,Ns).*nomove;
    flicker_img = 2*Ncol/255*imgQ(:,:,Ns).*flicker;

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
    

    % Write flicker/movement image to PNG file with comment string
    % providing the sequence length and 
    % number of colors in each color ramp
    commstr = sprintf('Ns=%0.0f, Ncol=%0.0f, frad=%0.0f', Ns, Ncol, frad);
    imwrite(outimg, cmap_out, [outdir filesep outfile], ...
            'comment', commstr);
    disp(['Written: ' outfile]);

    % Write the underlying stats to a data file if specified in function
    % call. This is primarily for diagnostics
    if statsout > 0
        statsfile = [outstem '_Qstats.mat'];
        save([outdir filesep statsfile], 'imgQ', ...
                                         'Qstd', ...
                                         'Qmean', ...
                                         'Qstdn');
    end
    
end

end
    
    