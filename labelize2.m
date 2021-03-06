function [r]=labelize(vertices, t_xyz, t_ref,varargin)
% labelize - labelize vertrices according to a reference template
%
% [r]=labelize(vertices, t_xyz, t_ref,['TimeBar'])
%
%     Each item of the vertices will be labeled with the t_ref value 
%     of the closest vertex in the t_xyz template (geometrical distance).
%
% Input:
%        vertices: [Nvx3] coordinates of Nv vertices for which labels are computed
%        t_xyz: [Ntx3] matrix, positions of the Nt template vertices
%        t_ref: [Ntx1] vector, labels of the template vertices
%
% Output:
%        r: [Nvx1] vector of the labels
%
% Options:
%        TimeBar  1 or 'on' to show a progress bar
if nargin>3
options=struct(varargin{:});
end
if isfield(options, 'TimeBar')
  if strmatch('on', lower(options.TimeBar))
    options.TimeBar=1;
  else
    options.TimeBar=0;
  end
else
  options.TimeBar=0;
end

r=zeros(length(vertices),1)*NaN;
if options.TimeBar
  h=timebar('Progres...','Labeling vertices');
end

nxyz=size(t_xyz,1);
nv=size(vertices,1);

for i=1:nv
  d=sum(power(t_xyz-repmat(vertices(i,:),nxyz,1),2),2);     
  
  % local "smoothing" 
  % r(i)=imax(hist(ref(d<5e-3), .5:length(labels)));        
  
  [r(i),r(i)]=min(d);    
  r(i)=t_ref(r(i));
  
  if options.TimeBar
    timebar(h, i/nv,1);
  end
  %set(p, 'FaceVertexCData',r); drawnow;w
end
if options.TimeBar
  close(h)
end

