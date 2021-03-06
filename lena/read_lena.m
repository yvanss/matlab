% read_lena() - read LENA header & data
%
% Usage:
%   [header] = read_lena(lenafile) reads only the header found in the LENA folder
%   >> [header data] = read_lena(lenafile) also reads the whole data
%   >> [header data] = read_lena(lenafile,DataSelection)
%   >> [header data] = read_lena(lenafile,OPTIONS)
%   >> [header data Time OPTIONS extras] = read_lena(lenafile,...)
%
% Required input:
%   lenafile = LENA header file
% Optional inputs:
%   The subset of data to read may be (more quickly) specified as a cell array:
%   DataSelection = { 1:4 [] -2} to read the first four elemnts of the
%   first dimension (e.g. the first 4 channels), all the 2nd dimension,
%   excluding the second sample of the third etc.
%
%   Alternatively, one may use an OPTIONS structure with any of those fields:
%       OPTIONS.DataSelection = (see above)
%       OPTIONS.SensorCategory = 'ALL' (default)|'MEG'|'EEG'|'EEG+MEG'|'DC'|'ADC'
%       OPTIONS.SensorName = '' (default) or any regexp string or a cell array
%       OPTIONS.Trials = Trials to read (default: [] = 'all')
%                        CAUTION: First Trial is #0
%       OPTIONS.TimeWindow = Start and end time in seconds (todo)
%       OPTIONS.XMLDepth -> Depth of the XML parsing (min. 3, default: 5)
%   This latter structure (OPTIONS) may also be provided as a list:
%   >> [header data] = read_lena(lenafile,'Trials',[1:N],'SensorName','FC'...)
%
% Outputs:
%   header = header info (from reading the xml heder file)
%   data = cell array of data (one cell by trial)
%   Time = Time vector for each sample
%   OPTIONS = struct (see above)
%   extras = structure with fields:
%           * classes
%           * events
%           * badchannels
%
% Requires: xml_read()
% See also:
%
% Author: Karim N'Diaye, CNRS-UPR640, 21 Apr 2010

% Copyright (C) 2004, CNRS - UPR640, N'Diaye Karim,
% karim.ndiaye@chups.jussieu.Fr
%
% This program is free software; you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation; either version 2 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program; if not, write to the Free Software
% Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

% $Log: readegi.m,v $
% Revision 0.1  2004/01/01
% First alpha version for EEGLAB release 4.301

function [header data Time options extras] = read_lena(lenafile,varargin)
if nargin < 1
    help(mfilename);
    return;
end
header = [];
data=[];
Time = [];
options = {};
extras = struct('classes',[] ,'events', [], 'badchannels', []);
if nargin<2
    options.DataSelection = { } ; % reads everything
end
%warning('Oh oh! There is a lot to read! It may take a while...');
data_selection = {};
data = [];

options.XMLDepth = 5;
if nargin>2
    if isstruct(varargin{1})
        fn = fieldnames(varargin{1});
        for i=1:numel(fn)
            options = setfield(options,fn{i},getfield(varargin{1},fn{i}));
        end
        varargin(1)=[];
    end
    if iscell(varargin) && numel(varargin) == 1
        options.DataSelection = varargin{1};
    else
        if mod(length(varargin),2) ~= 0
            error('Options should be given in pairs: ''Field1'', value1, etc.')
        end
        for i=1:2:length(varargin)
            options = setfield(options,varargin{i}, varargin{i+1});
        end
    end
end

if iscell(lenafile)
    header=cell(size(lenafile));
    for i=1:numel(lenafile)
        fprintf('Reading: %s\n', lenafile{i});
        switch nargout
            case 0;
            case 1
                [header{i}] = read_lena(lenafile{i},varargin{:});
            case 2
                data=cell(size(lenafile));
                [header{i} data{i}] = read_lena(lenafile{i},varargin{:});
            case 3
                data=header;
                Time=header;
                [header{i} data{i} Time{i}] = read_lena(lenafile{i},varargin{:});
        end
    end

    return
end
if not(exist(lenafile, 'file'))
    error('File/folder does not exist: %s', lenafile);
end

binary_extensions = {'.bin' '.data'};

canonical_dimensions = {
    'Sensor'   'sensor_range' ;
    'Time'     'time_range' ;
    'Trial'    'datablock_range' };

if exist(lenafile, 'dir') == 7
    %Folder = 2.0 format and above
    header_file = fullfile(lenafile, 'data.header');
else
    [p,r,e]=fileparts(lenafile);
    header_file = fullfile(p,[r, '.header']);
    if ~exist(header_file, 'file')
        header_file = lenafile;
    end
end

% The old version used 'xmltree' which is buggy with
% lena_tree = xmltree(header_file);
% warning('off', 'MATLAB:warn_r14_stucture_assignment')
% header = convert(lena_tree);
% warning('on', 'MATLAB:warn_r14_stucture_assignment')
%
% Indeed sensor info is lost:
% header.description.sensor_range.sensor_list(1).sensor{1}.coil
% is empty!
fprintf('Reading the header: %s...\n', header_file);

if isfield(options, 'XMLDepth')
    fprintf('Reading the XML to depth %d...\n', options.XMLDepth);
    header = xml_read(header_file, struct('NumLevels',options.XMLDepth));
else
    header = xml_read(header_file);
end

%% Exit if enough...
if nargout<2
    return
end
% Otherwise, it means that the user wants the binary data...
%% Read XML
if options.XMLDepth<4
    warning('read_lena:MinimalXMLDepth','The XML header must be read to a depth of at least 4 so as to import data');
    options.XMLDepth = 4;
    header = xml_read(header_file, struct('NumLevels',options.XMLDepth));
end

%% Time vector
if isfield(header.description, 'time_range')
Time = [1:header.description.time_range.time_samples]...
    ./header.description.time_range.sample_rate ...
    - header.description.time_range.pre_trigger;
else
    warning('read_lena:NoTimeRange', 'Data have no time range.');
    Time = [];
end
%% Data filename
if ~isfield(header, 'data_filename')
    header.data_filename ='';
    if exist(lenafile, 'dir')
        %new format
        data_filename = fullfile(lenafile, 'data.data');
    else
        for i=1:length(binary_extensions)
            [p,fn,ext]=fileparts(lenafile);
            fn = fullfile(p,fn);
            data_filename = [fn binary_extensions{i} ];
            if exist(data_filename, 'file')
                header.data_filename = data_filename;
                warning('I had to guess the binary data file since it was not specified in header...\nFound a possible match: %s\n', data_filename);
                break;
            end
        end
    end
else
    data_filename = header.data_filename;
end
if isempty(fileparts(data_filename))
    % If specified without path, assumed it is in the same folder as the
    % lena file
    data_filename = fullfile(fileparts(lenafile), data_filename);
end
if ~exist(data_filename, 'file')
    error('No binary data file found!')
end
fprintf('Data will be read from binary file: %s ...\n', data_filename)

%% Data format

if isfield(header, 'data_format') && strcmp(header.data_format,'LittleEndian')
    data_fid = fopen(data_filename,'r','l');
elseif isfield(header, 'data_format') && strcmp(header.data_format,'BigEndian')
    data_fid = fopen(data_filename,'r','b');
else
    warning('No data_format provided');
    data_fid = fopen(data_filename,'r');
end
if data_fid < 1
    error('Can''t open binary file');
end
% Read the offset because this info is not provided in header!
if isfield(header, 'data_offset')
    data_offset = header.data_offset;
else
    data_offset = 0 ;
end
% Get data type :
switch(header.data_type)
    case 'unsigned fixed'
        data_type='uint';
    case 'fixed'
        data_type='int';
    case 'floating'
        data_type='float';
    otherwise
        error('Error : data_type wasn t found, which is required.')
        return
end
% Get the data precision size :
data_precision = [];
switch header.data_type
    case 'unsigned fixed'
        data_type='uint';
    case 'fixed'
        data_type='int';
    case 'floating'
        data_type='float';
        if isfield(header, 'data_size') && header.data_size == 4
            data_precision = 'float32';
        end
    otherwise
        error('Error : data_type wasn t found, which is required.')
        return
end
if isempty(data_precision)
    error('Unknonw data precision/size/type');
end

%% Data dimensions
data_dimensions = fieldnames(header.description);
ndim = length(data_dimensions);
[ign,candim,dimcan] = intersect(canonical_dimensions(:,2), data_dimensions);
if any(dimcan(1:2) == 0) || any((candim-dimcan)~=0) || any(candim == 0)
    warning('read_lena:NonBrainstormDimensions',...
        ['Dimensions are not "brainstorm/eeglab" like (i.e. Sensor * Time * Epochs) but: ', ...
        sprintf('<%s> ',data_dimensions{:})])
end
% the nth canonical dim is the p-th one in the data
icandim(candim)=dimcan;
data_size=zeros(1,ndim);
for i=1:ndim
    switch (data_dimensions{i})
        case 'datablock_range'
            data_size(i) = numel(header.description.datablock_range.datablock_samples.trial);
        case 'sensor_range'
            data_size(i) = numel(header.description.sensor_range.sensor_samples.supersensor);
        case 'time_range'
            data_size(i) = header.description.time_range.time_samples;
        case 'frequency_range'
            data_size(i) = numel(header.description.frequency_range.frequency_samples.superfrequency);
        otherwise
            error('Wrong dimension')
    end
end

%% Data selection
% Expand (if needed) data_selection to the actual size of the data
if numel(data_selection)<ndim
    data_selection(end+1:ndim)={[]};
end
% If unset reads all data from all dimensions
for i_dim = 1:ndim
    if isempty(data_selection{i_dim})
        data_selection{i_dim} = 1:data_size(i_dim);
    elseif islogical(data_selection{i_dim})
        data_selection{i_dim} = find(data_selection{i_dim});
    elseif isnumeric(data_selection{i_dim})
        % do nothing
    elseif ischar(data_selection{i_dim})
        switch data_selection{i_dim}
            case 'all'
                data_selection{i_dim} = 1:data_size(i_dim);
            otherwise
                error('read_lena:UnknownKeyword',sprintf('Unknown keyword for data selection: %s', data_selection{i_dim}))
        end
    elseif iscell(data_selection{i_dim})
        if i_dim == icandim(2)
            error('to do')
        end
    end
end
% Now proceed with selctions defined as options
fn =fieldnames(options);
for i_field = 1:length(fn)
    switch fn{i_field}
        case 'SensorCategory'
            error('not yet')
            i_sensor(1,1:data_size(icandim(1))) = true ;
            if ~isequal(device, 'ALL')
                sensors = [header.description.sensor_range.sensor_list.sensor];
                sensornames = {sensors.CONTENT};
                sensorattribute = [sensors.ATTRIBUTE];
                if ischar(device); device = {device}; end
                i_sensor = false;
                for i=1:numel(device)
                    i_sensor = i_sensor | ~cellfun('isempty', regexpi(sensornames, device{i}));
                    i_sensor = i_sensor | ~cellfun('isempty', regexpi({sensorattribute.category}, device{i}));
                end
            end
            % boolean to indices
        case 'SensorName'
            s = {header.description.sensor_range.sensor_samples.supersensor.sensor};
            s = s(data_selection{icandim(1)});
            if ischar(options.SensorName)
                data_selection{icandim(1)} = find(~cellfun('isempty', regexpi(s, options.SensorName)));
            elseif isnumeric(options.SensorName)
                data_selection{icandim(1)} = options.SensorName;
            else % iscell(option.SensorName)
                error('not yet')
            end
        case 'Time'
            error('to correct')
            sel=1;
            if iscell(sel)
                [ data_selection{i_dim} dist ] = findclosest([ sel{1} sel{2} ], Time);
                data_selection{i_dim} = data_selection{i_dim}(1):data_selection{i_dim}(2);
                if any(dist>header.description.time_range.sample_rate)
                    error('Selection Time window goes by the Time range [%g .. %g] of the data!', Time([1 end]))
                end
            else
                error('Wrong Time selection (should be a 2x1 cell)')
            end

            data_selection{icandim(2)} = options.Time;
        case 'Trials'
            data_selection{icandim(3)} = options.Trials;
    end
end
for i_dim = 1:ndim
    if islogical(data_selection{i_dim})
        data_selection{i_dim} = find(data_selection{i_dim});
    end
end
if any(cellfun('isempty',data_selection))
    warning('read_lena:EmptySelection','According to options, data selection reduces to nill!')
    return
end
for i_dim = 1:ndim
    if any(abs(data_selection{i_dim})>data_size(i_dim))
        error('read_lena:SelectionBeyondRange','Selection of <%s> is beyond authorized range [ %g .. %g ]', ...
            data_dimensions{i_dim}, 1, data_size(i_dim))
    end
end

%% Data fread
% the fastest increasing dimension is the first and also the first one in
% the header, that is the 1st one unfolding in the binary data

h.data.filename = data_filename;
h.data.selection = data_selection;

[fread_size fread_precision fread_skip fread_offset fread_selection] = fread_options(data_size,data_selection,data_precision);
% Now reads the data
fprintf('... reading %d bytes of data ...\n',prod(fread_size));
fseek(data_fid,data_offset+fread_offset, 'bof');
data = fread(data_fid,prod(fread_size),fread_precision,fread_skip);
% Reshape data read into a matrix
data=reshape(data,fread_size);
% Extract the data if needed
for i=1:ndim
    data=subarray(data,fread_selection{i},i);
end
% Now permute so as to match the "natural" order of data_dimensions
data=permute(data,ndim:-1:1);


%% Read extra info (classes, etc.)
extras.classes = read_lena_classes(lenafile);
extras.events  = read_lena_events(lenafile);
%badchannels = read_lena_badchannels(lenafile);

return


function [fread_size fread_precision fread_skip fread_offset fread_selection] = fread_options(data_size,data_selection,data_precision)
% Optimal precision & skip to use in fread based on the shape of data
% The 'quick and dirty' way is to read all the data and select in the matrix afterwards... 
fread_size = fliplr(data_size);
fread_precision = data_precision;
fread_skip = 0; 
fread_offset = 0;
fread_selection = fliplr(data_selection);
return;
switch(data_precision)
    case {'uint8','int8','uchar','schar','char'}
        fread_bytes = 2;
    case {'uint16','int32','short','ushort'}
        fread_bytes = 2;
    case {'float32','single', 'float','uint32','int32','int','uint','long'}
        fread_bytes = 4;
    case {'float64','double','uint64','int64'}
        fread_bytes = 8;
    otherwise
        warning('read_lena:UnknownPrecision','Unknown precision: %s -- Go through the Full monthy', data_precision);
        return
end
ndim = numel(fread_size);
% Squeeze successive dimensions (beyond the first one) with only one sample to read
% Find the last squeezable dimension 
i = 1;
while i<ndim && (numel(fread_selection{i+1}) == 1)    
    i=i+1;
end
% The first segment to read starts after skipping a whole block of data
fread_offset = fread_offset + cumprod(fread_size(1:i-1)).*([fread_selection{2:i}]-1);

% To skip between each read
fread_skip = sum([1 fread_size(3:i-3)].*fread_size(2:i-1))*fread_size(1);

fread_size(2:i-1) = 1;
fread_selection(2:i-1) = 1;

fread_skip =  fread_offset + fread_skip + (data_size(end)-max(fread_selection{1})) ;
% Reads the largest continuous segments encompassing the requested range
% starting from the earliest sample
fread_offset = fread_offset + (min(fread_selection{1})-1) * fread_bytes;
fread_size(1) = max(fread_selection{1})-min(fread_selection{1})+1;
fread_precision = [ num2str(fread_size(1)) '*' data_precision];
fread_selection{1} = fread_selection{1}-min(fread_selection{1})+1;
%%
for i=ndim:-1:1
    if any(diff(data_selection{i})>1)
        break;
    end
end
if i==ndim
    skip = 0;
else

end
return


function [i dist] = findclosest(x,y)
x=x(:)';
y=y(:);
[dist i] = min(abs(repmat(x,length(y),1) - repmat(y,1,length(x))));

