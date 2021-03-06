function festr = fillExport(propnames, raw, parentName)
hdrstr = 'function refs = export(obj, fid, fullpath, refs)';
isRoot = strcmp(parentName, 'types.untyped.MetaClass');
if isRoot
    bodystr = {};
else
    bodystr = {strjoin({...
        ['refs = export@' parentName '(obj, fid, fullpath, refs);']...
        'if any(strcmp(refs, fullpath))'...
        '    return;'...
        'end'...
        }, newline)};
end

if isRoot
    if isa(raw, 'file.Group')
        bodystr = [bodystr {'io.writeGroup(fid, fullpath);'}];
    elseif isa(raw, 'file.Dataset')
        %find the `data` field for the respective dataset
        bodystr = [bodystr {strjoin({...
            'try'...
            '    if isa(obj.data, ''types.untyped.DataStub'')'...
            '        refs = obj.data.export(fid, fullpath, refs);'...
            '    elseif istable(obj.data) || isstruct(obj.data) || isa(obj.data, ''containers.Map'')'...
            '        io.writeCompound(fid, fullpath, obj.data);'...
            '    else'...
            '        io.writeDataset(fid, fullpath, class(obj.data), obj.data);'...
            '    end'...
            'catch ME'...
            '    if strcmp(ME.stack(2).name, ''getRefData'') && ...'...
            '          endsWith(ME.stack(1).file, ...'...
            '            fullfile({''+H5D'',''+H5R''}, {''open.m'', ''create.m''}))'...
            '        refs = [refs {fullpath}];'...
            '        return;'...
            '    else'...
            '        rethrow(ME);'...
            '    end'...
            'end'...
            }, newline)}];
        %filter propnames to remove data prop
        propnames = propnames(~strcmp(propnames, 'data'));
    end
elseif isa(raw, 'file.Group') && strcmp(raw.type, 'NWBFile')
    %NWBFile is technically the root `group`, which in HDF5 is a single `/`
    % this messes with property creation so we reassign the path here to
    % empty string so concatenation looks right
    bodystr = [bodystr {'fullpath = '''';'}];
end

if isRoot
    %Metaclass needs to be added after the class is made
    bodystr = [bodystr...
        {'refs = export@types.untyped.MetaClass(obj, fid, fullpath, refs);'}];
end

for i=1:length(propnames)
    pnm = propnames{i};
    pathProps = traverseRaw(pnm, raw);
    prop = pathProps{end};
    pathProps(end) = []; %delete prop
    
    %construct path for groups
    elisions = '';
    while ~isempty(pathProps) && isa(pathProps{1}, 'file.Group')
        elisions = [elisions '/' pathProps{1}.name];
        pathProps = pathProps(2:end);
    end
    elisions = elisions(2:end);
    propstr = '';
    if isempty(pathProps) && ~isempty(elisions)
        propstr = ['io.writeGroup(fid, [fullpath ''/' elisions ''']);'];
    elseif ~isempty(pathProps)
        %this property is dependent on an untyped dataset
        propname = pathProps{1}.name;
        if isempty(elisions)
            elisions = propname;
        else
            elisions = [elisions '/' propname];
        end
    end
    bodystr = [bodystr {propstr} {fillDataExport(pnm, prop, elisions)}];
end

festr = strjoin({hdrstr...
    file.addSpaces(strjoin(bodystr, newline), 4)...
    'end'}, newline);
end

function path = traverseRaw(propname, raw)
path = {};
switch class(raw)
    case 'file.Group'
        %get names of both subgroups and datasets
        gnames = {};
        dsnames = {};
        lnknames = {};
        anames = {};
        
        if ~isempty(raw.attributes)
            anames = {raw.attributes.name};
        end
        
        if ~isempty(raw.subgroups)
            gnames = {raw.subgroups.name};
            lowerGroupTypes = lower({raw.subgroups.type});
            useLower = [raw.subgroups.isConstrainedSet] | cellfun('isempty', gnames);
            gnames(useLower) = lowerGroupTypes(useLower);
        end
        
        if ~isempty(raw.datasets)
            dsnames = {raw.datasets.name};
            lowerDsTypes = lower({raw.datasets.type});
            useLower = [raw.datasets.isConstrainedSet];
            dsnames(useLower) = lowerDsTypes(useLower);
        end
        
        if ~isempty(raw.links)
            lnknames = {raw.links.name};
        end
        
        if any(strcmp([anames gnames dsnames lnknames], propname))
            amatch = strcmp(anames, propname);
            gmatch = strcmp(gnames, propname);
            dsmatch = strcmp(dsnames, propname);
            lnkmatch = strcmp(lnknames, propname);
            if any(amatch)
                path = {raw.attributes(amatch)};
            elseif any(gmatch)
                path = {raw.subgroups(gmatch)};
            elseif any(dsmatch)
                path = {raw.datasets(dsmatch)};
            elseif any(lnkmatch)
                path = {raw.links(lnkmatch)};
            end
            return;
        end
        
        %find true path for elided property
        if startsWith(propname, dsnames) || startsWith(propname, gnames)
            for i=1:length(gnames)
                nm = gnames{i};
                suffix = propname(length(nm)+2:end);
                if startsWith(propname, nm)
                    res = traverseRaw(suffix, raw.subgroups(i));
                    if ~isempty(res)
                        path = [{raw.subgroups(i)} res];
                        return;
                    end
                end
            end
            for i=1:length(dsnames)
                nm = dsnames{i};
                suffix = propname(length(nm)+2:end);
                if startsWith(propname, nm)
                    res = traverseRaw(suffix, raw.datasets(i));
                    if ~isempty(res)
                        path = [{raw.datasets(i)} res];
                        return;
                    end
                end
            end
        end
    case 'file.Dataset'
        attrmatch = strcmp({raw.attributes.name}, propname);
        if any(attrmatch)
            path = {raw.attributes(attrmatch)};
        end
end
end

function fde = fillDataExport(name, prop, elisions)
if isempty(elisions)
    fullpath = ['[fullpath ''/' prop.name ''']'];
    elisionpath = 'fullpath';
else
    fullpath = ['[fullpath ''/' elisions '/' prop.name ''']'];
    elisionpath = ['[fullpath ''/' elisions ''']'];
end

if (isa(prop, 'file.Group') || isa(prop, 'file.Dataset')) && prop.isConstrainedSet
    fde = ['refs = obj.' name '.export(fid, ' elisionpath ', refs);'];
elseif isa(prop, 'file.Link') || isa(prop, 'file.Group') ||...
        (isa(prop, 'file.Dataset') && ~isempty(prop.type))
    % obj, loc_id, path, refs
    fde = ['refs = obj.' name '.export(fid, ' fullpath ', refs);'];
elseif isa(prop, 'file.Dataset') %untyped dataset
    fde = strjoin({...
        ['if startsWith(class(obj.' name '), ''types.untyped.'')']...
        ['    refs = obj.' name '.export(fid, ' fullpath ', refs);']...
        ['elseif ~isempty(obj.' name ')']...
        ['    io.writeDataset(fid, ' fullpath ', class(obj.' name '), obj.' name ');']...
         'end'...
        }, newline);
else
    fde = ['io.writeAttribute(fid, ''' prop.dtype ''', ' fullpath ', obj.' name ');'];
end

emptycheck = ['if ~isempty(obj.' name ')'];

if isa(prop, 'file.Attribute') && ~isempty(prop.dependent)
    %if attribute is dependent, check before writing
    if isempty(elisions) || strcmp(elisions, prop.dependent)
        depPropname = prop.dependent;
    else
        flattened = strfind(elisions, '/');
        flattened = strrep(elisions(1:flattened(end)), '/', '_');
        depPropname = [flattened prop.dependent];
    end
    emptycheck = [emptycheck ' && ~isempty(obj.' depPropname ')'];
end

fde = [emptycheck newline file.addSpaces(fde, 4)];

if prop.required
    errmsg = ['    error(''Property `' name '` is required.'');'];
    if isa(prop, 'file.Attribute') && ~isempty(prop.dependent)
        errmsg = ['elseif ~isempty(obj.' depPropname ')' newline errmsg];
    else
        errmsg = ['else' newline errmsg];
    end
    fde = [fde newline errmsg];
end

fde = [fde newline 'end'];

end