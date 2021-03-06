classdef ElectricalSeriesIOTest < tests.system.PyNWBIOTest
    methods(Test)
        function testOutToPyNWB(testCase)
            testCase.assumeFail(['Current schema in MatNWB does not include a ElectrodeTable class used by Python tests. ', ...
                'When it does, addContainer in this test will need to be updated to match the Python test']);
        end
        
        function testInFromPyNWB(testCase)
            testCase.assumeFail(['Current schema in MatNWB does not include a ElectrodeTable class used by Python tests. ', ...
                'When it does, addContainer in this test will need to be updated to match the Python test']);
        end
    end
    
    methods
        function addContainer(testCase, file) %#ok<INUSL>
            devnm = 'dev1';
            egnm = {'tetrode1';'tetrode2'};
            esnm = 'test_eS';
            devBase = '/general/devices/';
            ephysBase = '/general/extracellular_ephys/';
            devlink = types.untyped.SoftLink([devBase devnm]);
            eglink = types.untyped.ObjectView([ephysBase egnm{1}]);
            eglink2 = types.untyped.ObjectView([ephysBase egnm{2}]);
            etReg = types.untyped.RegionView([ephysBase 'electrodes'], 1, 2);
            dev = types.core.Device('source', 'a test source');
            file.general_devices.set(devnm, dev);
            eg = [...
                types.core.ElectrodeGroup( ...
                'source', 'a test source', ...
                'description', 'tetrode description', ...
                'location', 'tetrode location', ...
                'device', devlink);...
                types.core.ElectrodeGroup(...
                'source', 'test source 2', ...
                'description', 'testrode desc', ...
                'location', 'tetrode2 location', ...
                'device', devlink)];
            
            etdata = [struct(...
                'id', int64(1), 'x', rand(), 'y', rand(), 'z', rand(), ...
                'imp', rand(), 'location', '', 'filtering', '', ...
                'description', 'test', 'group', eglink, ...
                'group_name', 'tetrode1');...
                struct(...
                'id', int64(2), 'x', rand(), 'y', rand(), 'z', rand(), ...
                'imp', rand(), 'location', '', 'filtering', '', ...
                'description', 'test2', 'group', eglink2, ...
                'group_name', 'tetrode2')];
            
            file.general_extracellular_ephys.set('electrodes', ...
                types.core.ElectrodeTable('data', etdata));
            file.general_extracellular_ephys.set(egnm, eg);
            es = types.core.ElectricalSeries( ...
                'source', 'a hypothetical source', ...
                'data', int32([0:9;10:19]) .', ...
                'timestamps', (0:9) .', ...
                'electrodes', ...
                types.core.ElectrodeTableRegion(...
                'data', etReg,...
                'description', 'test etr'));
            file.acquisition.set(esnm, es);
        end
        
        function c = getContainer(testCase, file) %#ok<INUSL>
            c = file.acquisition.get('test_eS');
        end
    end
end

