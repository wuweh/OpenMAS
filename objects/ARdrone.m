%% ARDRONE DYNAMIC MODEL (ARdrone.m) %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This class contains the dynamic properties of an ARdrone, along with all
% the necessary control parameters that can be derived from the model
% parameters.

% Author: James A. Douthwaite

classdef ARdrone < agent
%%% ARdrone CHILD CLASS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % This class defines the ARdrone specific properties for importing a
    % small quadrotor into the environment.
    
    %% ////////////////// ADRONE SPECIFIC PARAMETERS //////////////////////
    properties
        config = 'OUTDOOR';
        % Performance Parameters
        battery_capacity  = 1000;     % Maximum battery capacity (mAh)
        battery_voltage   = 11.1;     % Maximum battery voltage (V)
        flight_time       = 720;      % Rated flight time (s)
        dt = -1;                      % The linearisation time-step (Assume continuous intially)
    end
    %% ////////////////////// MAIN CLASS METHODS //////////////////////////
    methods 
        % Constructor
        function [this] = ARdrone(varargin)
            % This function is to construct the ARdrone object using the
            % object defintions held in the 'agent' class.
            % INPUTS:
            % namestr - Assigned name string
            % OUTPUTS:
            % obj     - The constructed object

            
            % CALL THE SUPERCLASS CONSTRUCTOR
            this = this@agent(varargin);
            
            % Assign ARdrone parameters
            this.GEOMETRY = this.CreateGEOMETRY();
            this.DYNAMICS = this.CreateDYNAMICS();    % Get the dynamic parameters
            this.SENSORS  = this.CreateSENSORS();     % Get the sensor parameters
            this.radius   = this.GEOMETRY.length/2;   % Reaffirm radius against .VIRTUAL
            
            % //////////////// Check for user overrides ///////////////////            
            % - It is assumed that overrides to the properties are provided
            %   via the varargin structure.
            [this] = this.ApplyUserOverrides(varargin); 
            % Recursive overrides % Initialise memory structure (with 2D varient)             
            % /////////////////////////////////////////////////////////////
        end
        % Setup - LOCAL STATE [x;x_dot]'
        function [this] = setup(this,localXYZVelocity,localXYZrotations)
            % This function generates the initial state vector for the
            % ARdrone model from the global parameters provided from the
            % scenario.

            % DEFINE THE INITIAL STATE
            this.localState = zeros(12,1);
            
            % MAPPING FROM XYZ CONVENTION TO THE NED CONVENTION
            this.localState(4:6) = enu2ned(localXYZrotations);
            this.localState(7:9) = enu2ned(localXYZVelocity);
            
            % Capture the prior state
            this = this.SetGLOBAL('priorState',this.localState); % Record the previous state
        end
        % THIS CLASS HAS NO 'main' CYCLE
        % The ARdrone class is designed to simply provide the dynamics of a
        % ARdrone quadrotor MAV.
    end
    %% /////////////////////// AUXILLARY METHODS //////////////////////////
    methods (Static)
        % GET THE NOMINAL THRUST INPUTS FROM CURRENT STATE
        function [Uss] = ARdrone_nominalInput(X)
            %#codegen

            %    This function was generated by the Symbolic Math Toolbox version 8.1.
            %    17-Jul-2018 15:14:14

            PHI_t = X(4,:);
            THETA_t = X(5,:);
            t2 = 3.875420890636849e8;
            t3 = cos(PHI_t);
            t4 = cos(THETA_t);
            t5 = t3.*t4;
            t6 = sqrt(t5);
            t7 = t2.*t6.*4.675627089909692e-7;
            Uss = [t7;t7;t7;t7];
        end
        % CONTROL MAPPING FOR ARDRONE
        function [Vin] = ARdrone_controlMapping(throttle,roll,pitch,yaw)
            % This function maps the body axis torques onto the angular
            % rate set points of the motors (omega_(1-4))
            Vin = zeros(4,1);
            Vin(1) = throttle - roll + pitch - yaw;
            Vin(2) = throttle - roll - pitch + yaw;
            Vin(3) = throttle + roll - pitch - yaw;
            Vin(4) = throttle + roll + pitch + yaw; % This distributes the control inputs to the respective 
        end        
    end
    %% ////////////////////// PROPERTY ASSIGNMENTS ////////////////////////
    methods 
        % Get the (ARdrone) DYNAMICS structure
        function [DYNAMICS] = CreateDYNAMICS(this)
            % This function imports the complete set of dynamic properties
            % for the ARdrone 2.0 quadrotor UAV.
            
            % Get the default structure
            [DYNAMICS] = this.CreateDYNAMICS_default();
            
            % ALTER THE DYNAMICS BASED ON THE CONFIGURATION
            switch upper(this.config)
                case 'NONE'
                    DYNAMICS.m = 0.366;
                case 'OUTDOOR'
                    DYNAMICS.m = 0.400; % Arm length equiv : 0.3196
                case 'INDOOR'
                    DYNAMICS.m = 0.436;
                otherwise
                    error('Configuration not recognised');
            end
            % INERTIAL MATRIX (x) configuration (FICTIONAL I MATRIX)
            DYNAMICS.I = 1.0E-06.*[...
                2.8032E+04,0.0000E+00,0.0000E+00;
                0.0000E+00,2.8032E+04,0.0000E+00;
                0.0000E+00,0.0000E+00,2.8023E+04];
            % GET THE LINEAR STATE SPACE MODEL
            %             I_b11 = DYNAMICS.I(1,1);
            %             I_b22 = DYNAMICS.I(2,2);
            %             I_b33 = DYNAMICS.I(3,3);
            %             m_b = 0.400;
            %             kt = 1.4939E-05;
            %             kh = 1.1700E-05;
            %             l = 0.3196;
            g = 300978377846937375/30680772461461504;
            % PLANT MATRIX
            A = [...
                0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0;
                0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0;
                0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0;
                0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0;
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0;
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1;
                0, 0, 0, 0,-g, 0, 0, 0, 0, 0, 0, 0;
                0, 0, 0, g, 0, 0, 0, 0, 0, 0, 0, 0;
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0;
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0;
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0;
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            
            % INPUT MATRIX
            B = [...
                0,                                                      0,                                                      0,                                                     0;
                0,                                                      0,                                                      0,                                                     0;
                0,                                                      0,                                                      0,                                                     0;
                0,                                                      0,                                                      0,                                                     0;
                0,                                                      0,                                                      0,                                                     0;
                0,                                                      0,                                                      0,                                                     0;
                0,                                                      0,                                                      0,                                                     0;
                0,                                                      0,                                                      0,                                                     0;
                -1377879548585735/18446744073709551616,                 -1377879548585735/18446744073709551616,                 -1377879548585735/18446744073709551616,                -1377879548585735/18446744073709551616;
                -(5504628796600011325*2^(1/2))/32318695617139134431232, -(5504628796600011325*2^(1/2))/32318695617139134431232,  (5504628796600011325*2^(1/2))/32318695617139134431232, (5504628796600011325*2^(1/2))/32318695617139134431232;
                (5504628796600011325*2^(1/2))/32318695617139134431232, -(5504628796600011325*2^(1/2))/32318695617139134431232, -(5504628796600011325*2^(1/2))/32318695617139134431232, (5504628796600011325*2^(1/2))/32318695617139134431232;
                27848632988697/33350523172745984,                      -27848632988697/33350523172745984,                       27848632988697/33350523172745984,                     -27848632988697/33350523172745984];

            % DEFINE THE CONTINUOUS-TIME STATESPACE MODEL
            C = eye(12);                       % Build the observation matrix
            D = zeros(size(A,1),size(B,2));    % Build the feed-forward matrix
            
            % CONVERT TO THE DESCRETE STATE-SPACE MODEL
            SS = ss(A,B,C,D);                  % Matlab continous statespace object
            DYNAMICS.SS = SS;
            % SYS = c2d(SYS,dt,'zoh');         % Convert the continuous statespace model to descrete.
            

            % GET THE INVERTED DYNAMICS MATRIX (STEADY STATE CALCULATION)
            SSmatrix = [(eye(size(SS.A,2))-SS.A),-SS.B; SS.C, SS.D];  % Defines the relationship between the dynamics and the stead state set-point
            DYNAMICS.invSSmatrix = pinv(SSmatrix);
            
            % DEFINE THE NOMINAL CONTROL INPUT (HOVER INPUT)
            aNom = [-g;0;0;0];
            DYNAMICS.Uss = sqrt(inv(SS.B(9:12,:))*aNom);
            
            % THE TRANSFER FUNCTION (omega -> thrust)
            %             descrete_tf = tf(1,[0.108 1],dt);
            %             [A,B,C,D] = tf2ss(1,[0.108 1])
            %             DYNAMICS.rotorSS = ss(A,B,C,D);
            
            % CONSTANT DYNAMIC PARAMETERS
            DYNAMICS.omega_max = 750;                                      % Maximum angular rotor speed (rad/s)
            DYNAMICS.omega_min = 0;
        end
        % Get the (ARdrone) GEOMETRY structure
        function [GEOMETRY] = CreateGEOMETRY(this)
            
            % Parse the geometry associated with the object
            [GEOMETRY] = this.GetObjectGeometry(this);
            
            % ALTER THE DYNAMICS BASED ON THE CONFIGURATION
            switch upper(this.config)
                case 'NONE'
                    GEOMETRY.width  = 0.450;
                    GEOMETRY.length = 0.290;
                case 'OUTDOOR'
                    GEOMETRY.width  = 0.452;
                    GEOMETRY.length = 0.452; % Arm length equiv : 0.3196
                case 'INDOOR'
                    GEOMETRY.width  = 0.515;
                    GEOMETRY.length = 0.515;
                otherwise
                    error('Configuration not recognised');
            end
        end
        % Get the (ARdrone) SENSOR structure
        function [SENSORS]  = CreateSENSORS(this)
            % This function gets the ARdrone 2.0's sensor-specific data and
            % imports them to OMAS's obj.SENSOR structure.
            
            % Get the default SENSOR structure
            SENSORS = this.SENSORS;
            SENSORS.ultrasound_freq = 40E3;     % Ultrasonic range-finder frequency (Hz)
            SENSORS.ultrasound_range = 6;       % Ultrasonic range-fidner range (m)
            SENSORS.camera_freq = 30;           % Camera capture frequency (fps)      
        end 
    end
    %% /////////////////////// MODELLING/DYNAMICS /////////////////////////
    methods
        % GET THE STATE UPDATE (USING ODE45)
        function [X] = UpdateNonLinearPlant(this,ENV,X0,U)
            % This function computes the state update for the current agent
            % using the ode45 function.
            
            X = X0; % Default to no change
            
            % DETERMINE THE INTEGRATION PERIOD
            if ENV.currentTime ~= ENV.timeVector(end)
                % INTEGRATE THE DYNAMICS OVER THE TIME STEP 
                [~,Xset] = ode45(@(t,X) this.ARdrone_nonLinear_openLoop(X,U),...
                    [0 ENV.dt],X0,odeset('RelTol',1e-2,'AbsTol',ENV.dt*1E-2));
                X = Xset(end,:)';
            end
        end 
        % GET THE STATE UPDATE (USING ODE45)
        function [X] = UpdateLinearPlant(this,ENV,X0,U)
            % This function computes the state update for the current agent
            % using the ode45 function.
            
            X = X0; % Default to no change
            
            % DETERMINE THE INTEGRATION PERIOD
            if ENV.currentTime ~= ENV.timeVector(end)
                % INTEGRATE THE DYNAMICS OVER THE TIME STEP 
                [~,Xset] = ode45(@(t,X) this.ARdrone_linear_openLoop(this.SYS,X,U),...
                    [0 ENV.dt],X0,odeset('RelTol',1e-2,'AbsTol',ENV.dt*1E-2));
                X = Xset(end,:)';
            end
        end
    end
    methods (Static)
        % THE NONLINEAR AR-DRONE PLANT ODES
        function [dX] = ARdrone_nonLinear_openLoop(X,U)
            %#codegen
            
            %    This function was generated by the Symbolic Math Toolbox version 8.1.
            %    17-Jul-2018 15:13:41
            
            PHI_t = X(4,:);
            PHI_dot = X(10,:);
            PSI_dot = X(12,:);
            THETA_t = X(5,:);
            THETA_dot = X(11,:);
            omega_1 = U(1,:);
            omega_2 = U(2,:);
            omega_3 = U(3,:);
            omega_4 = U(4,:);
            x_dot = X(7,:);
            y_dot = X(8,:);
            z_dot = X(9,:);
            t2 = cos(PHI_t);
            t3 = cos(THETA_t);
            t4 = sin(PHI_t);
            t5 = sin(THETA_t);
            t6 = omega_1.^2;
            t7 = sqrt(2.0);
            t8 = omega_2.^2;
            t9 = omega_3.^2;
            t10 = omega_4.^2;
            t11 = t7.*t9.*8.516167950913242e-5;
            t12 = t7.*t10.*8.516167950913242e-5;
            t13 = PSI_dot.^2;
            dX = [x_dot;y_dot;z_dot;PHI_dot;THETA_dot;PSI_dot;t5.*(-9.81e2./1.0e2)+THETA_dot.*t4.*y_dot+THETA_dot.*t2.*z_dot-PSI_dot.*t2.*t3.*y_dot+PSI_dot.*t3.*t4.*z_dot;-PHI_dot.*z_dot+t3.*t4.*(9.81e2./1.0e2)+PSI_dot.*t5.*z_dot-THETA_dot.*t4.*x_dot+PSI_dot.*t2.*t3.*x_dot;t6.*(-3.73475e-5)-t8.*3.73475e-5-t9.*3.73475e-5-t10.*3.73475e-5+PHI_dot.*y_dot+t2.*t3.*(9.81e2./1.0e2)-PSI_dot.*t5.*y_dot-THETA_dot.*t2.*x_dot-PSI_dot.*t3.*t4.*x_dot;t11+t12+THETA_dot.*omega_1.*3.231842180365297e-3-THETA_dot.*omega_2.*3.231842180365297e-3+THETA_dot.*omega_3.*3.231842180365297e-3-THETA_dot.*omega_4.*3.231842180365297e-3-t6.*t7.*8.516167950913242e-5-t7.*t8.*8.516167950913242e-5-THETA_dot.^2.*t4.*9.996789383561644e-1-PSI_dot.*THETA_dot.*t2-t3.*t4.*t13+PSI_dot.*THETA_dot.*t2.*t3.*9.996789383561644e-1;-t11+t12+PHI_dot.*PSI_dot-PHI_dot.*omega_1.*3.231842180365297e-3+PHI_dot.*omega_2.*3.231842180365297e-3-PHI_dot.*omega_3.*3.231842180365297e-3+PHI_dot.*omega_4.*3.231842180365297e-3+t6.*t7.*8.516167950913242e-5-t7.*t8.*8.516167950913242e-5-t5.*t13+PHI_dot.*THETA_dot.*t4.*9.996789383561644e-1-PHI_dot.*PSI_dot.*t2.*t3.*9.996789383561644e-1;t6.*4.175141847767905e-4-t8.*4.175141847767905e-4+t9.*4.175141847767905e-4-t10.*4.175141847767905e-4-PHI_dot.*THETA_dot.*1.000321164757521+PHI_dot.*THETA_dot.*t2.*1.000321164757521+PSI_dot.*THETA_dot.*t5.*1.000321164757521+PHI_dot.*PSI_dot.*t3.*t4.*1.000321164757521];
        end
        % THE LINEAR (SS) AR-DRONE PLANT
        function [dX] = ARdrone_linear_openLoop(X,U)
            % This function computes the state update using the derived
            % linear model of the ARdrone. The system is assumed linearised
            % around the hover condition, therefore the state-space model is
            % considered to be the change about this condition (i.e. the
            % inputs are delta_omega.^2
            
            % COMPUTE THE STATE UPDATE (i.e. Xdot = (A*x + B*du))
            PHI_t = X(4,:);
            PHI_dot = X(10,:);
            PSI_dot = X(12,:);
            THETA_t = X(5,:);
            THETA_dot = X(11,:);
            omega_1 = U(1,:);
            omega_2 = U(2,:);
            omega_3 = U(3,:);
            omega_4 = U(4,:);
            x_dot = X(7,:);
            y_dot = X(8,:);
            z_dot = X(9,:);
            t2 = omega_1.^2;
            t3 = sqrt(2.0);
            t4 = omega_2.^2;
            t5 = omega_3.^2;
            t6 = omega_4.^2;
            t7 = t3.*t5.*1.703233590182648e-4;
            t8 = t3.*t6.*1.703233590182648e-4;
            dX = [x_dot;y_dot;z_dot;PHI_dot;THETA_dot;PSI_dot;THETA_t.*(-9.81e2./1.0e2);PHI_t.*(9.81e2./1.0e2);t2.*(-7.4695e-5)-t4.*7.4695e-5-t5.*7.4695e-5-t6.*7.4695e-5;t7+t8-t2.*t3.*1.703233590182648e-4-t3.*t4.*1.703233590182648e-4;-t7+t8+t2.*t3.*1.703233590182648e-4-t3.*t4.*1.703233590182648e-4;t2.*8.35028369553581e-4-t4.*8.35028369553581e-4+t5.*8.35028369553581e-4-t6.*8.35028369553581e-4];
        end 
    end
    % ///////////////////////// OMAS INTERFACES ///////////////////////////
    methods 
        % UNIQUE GLOBAL UPDATE FOR [x;x_dot]'
        function [obj] = GlobalUpdate_ARdrone(obj,dt,eulerState)
            % This function preforms the state update for a state vector
            % defined as [x y z phi theta psi dx dy dz dphi dtheta dpsi].
            
%             positionIndices = 1:3;
%             angleIndices = 4:6;
            % EQUIVALENT RATES
            v_k_plus = eulerState(7:9,1);
            localAxisRates  = eulerState(10:12,1);  
            
            % Define prior properties
            p_k = obj.GetGLOBAL('position');
            v_k = obj.GetGLOBAL('velocity');
            q_k = obj.GetGLOBAL('quaternion');   % XYZ QUATERNION

            
%             velocity_k_plus = (eulerState(positionIndices) - obj.VIRTUAL.priorState(positionIndices))/dt;
%             localAxisRates  = (eulerState(angleIndices) - obj.VIRTUAL.priorState(angleIndices))/dt; 
            
%             % IF ALL WAYPOINTS ARE ACHEIVED; FREEZE THE AGENT
%             if isprop(obj,'targetWaypoint')
%                 if isempty(obj.targetWaypoint) && ~isempty(obj.achievedWaypoints)
%                     obj.VIRTUAL.idleStatus = logical(true);
%                     velocity_k_plus = zeros(numel(positionIndices),1);     % Freeze the agent
%                     localAxisRates  = zeros(numel(angleIndices),1);         % Freeze the agent
%                 end
%             end
            
            % MAP THE LOCAL RATES TO GLOBAL RATES AND INTEGRATE QUATERNION
            % PREVIOUS QUATERNION                                          % [ IF THE QUATERNION DEFINES GB ]
            
            % PREVIOUS ROTATION-MATRIX
            R_k = OMAS_geometry.quaternionToRotationMatrix(q_k);     % XYZ ROTATION
%             mapAngle = pi;
%             XYZ2NED = [ 1             0              0;
%                         0 cos(mapAngle) -sin(mapAngle);
%                         0 sin(mapAngle)  cos(mapAngle)];
            mapAngle = pi;        
            NED2XYZ = [ 1             0              0;
                        0 cos(mapAngle) -sin(mapAngle);
                        0 sin(mapAngle)  cos(mapAngle)];
                    
            % THE GLOBAL AXIS RATES       
            omega = R_k'*(NED2XYZ*localAxisRates);
            
            % UPDATE THE QUATERNION POSE
            q_k_plus = OMAS_geometry.integrateQuaternion(q_k,omega,dt);
            % REDEFINE THE ROTATION MATRIX
            R_k_plus = OMAS_geometry.quaternionToRotationMatrix(q_k_plus);
            
            % MAP THE LOCAL VELOCITY TO THE GLOBAL AXES
            v_k_plus = R_k_plus'*(NED2XYZ*v_k_plus);
            p_k_plus = p_k + dt*v_k;
            % ///////////////// REASSIGN K+1 PARAMETERS ///////////////////
            [obj] = obj.GlobalUpdate_direct(...
                p_k_plus,...    % Global position at k plius
                v_k_plus,...    % Global velocity at k plus
                q_k_plus);      % Quaternion at k plus
        end
    end
end