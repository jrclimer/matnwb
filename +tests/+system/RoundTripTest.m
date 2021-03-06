classdef RoundTripTest < matlab.unittest.TestCase
    properties
        %     registry
        file
        root;
    end
    
    methods(TestClassSetup)
        function setupClass(testCase)
            rootPath = fullfile(fileparts(mfilename('fullpath')), '..', '..');
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(rootPath));
            testCase.root = rootPath;
        end
    end
    
    methods(TestMethodSetup)
        function setupMethod(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            generateCore(fullfile(testCase.root, ...
                'schema', 'core', 'nwb.namespace.yaml'));
            testCase.file = nwbfile( ...
                'source', 'a test source', ...
                'session_description', 'a test NWB File', ...
                'identifier', 'TEST123', ...
                'session_start_time', datestr([1970, 1, 1, 12, 0, 0], 'yyyy-mm-dd HH:MM:SS'), ...
                'file_create_date', datestr([2017, 4, 15, 12, 0, 0], 'yyyy-mm-dd HH:MM:SS'));
            testCase.addContainer(testCase.file);
        end
    end
    
    methods(Test)
        function testRoundTrip(testCase)
            filename = ['MatNWB.' testCase.className() '.testRoundTrip.nwb'];
            nwbExport(testCase.file, filename);
            writeContainer = testCase.getContainer(testCase.file);
            readFile = nwbRead(filename);
            readContainer = testCase.getContainer(readFile);
            testCase.verifyContainerEqual(readContainer, writeContainer);
        end
    end
    
    methods
        function n = className(testCase)
            classSplit = strsplit(class(testCase), '.');
            n = classSplit{end};
        end
        
        function verifyContainerEqual(testCase, actual, expected)
            testCase.verifyEqual(class(actual), class(expected));
            props = properties(actual);
            for i = 1:numel(props)
                prop = props{i};
                if strcmp(prop, 'file_create_date')
                    continue;
                end
                val1 = actual.(prop);
                val2 = expected.(prop);
                failmsg = ['Values for property ''' prop ''' are not equal'];
                if startsWith(class(val1), 'types.core.')
                    verifyContainerEqual(testCase, val1, val2);
                elseif isa(val1, 'types.untyped.Set')
                    verifySetEqual(testCase, val1, val2, failmsg);
                else
                    if isa(val1, 'types.untyped.DataStub')
                        trueval = val1.load();
                    else
                        trueval = val1;
                    end
                    
                    if isvector(val2) && isvector(trueval)
                        trueval = reshape(trueval, size(val2));
                    end
                    testCase.verifyEqual(trueval, val2, failmsg);
                end
            end
        end
        
        function verifySetEqual(testCase, actual, expected, failmsg)
            testCase.verifyEqual(class(actual), class(expected));
            ak = actual.keys();
            ek = expected.keys();
            verifyTrue(testCase, isempty(setxor(ak, ek)), failmsg);
            for i=1:numel(ak)
                key = ak{i};
                verifyContainerEqual(testCase, actual.get(key), ...
                    expected.get(key)); 
            end
        end
        
        function verifyUntypedEqual(testCase, actual, expected)
            testCase.verifyEqual(class(actual), class(expected));
            props = properties(actual);
            for i = 1:numel(props)
                prop = props{i};
                val1 = actual.(prop);
                val2 = expected.(prop);
                if isa(val1, 'types.core.NWBContainer') || isa(val1, 'types.core.NWBData')
                    verifyContainerEqual(testCase, val1, val2);
                else
                    testCase.verifyEqual(val1, val2, ...
                        ['Values for property ''' prop ''' are not equal']);
                end
            end
        end
        
    end
    
    methods(Abstract)
        addContainer(testCase, file);
        c = getContainer(testCase, file);
    end
    
end