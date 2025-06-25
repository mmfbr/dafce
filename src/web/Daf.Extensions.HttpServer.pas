unit Daf.Extensions.HttpServer;

interface
uses
  System.Classes,
  System.SysUtils;

type
  IDafHttpServer = interface(IInvokable)
    function GetIndyVersion: string;
    function GetSessionID: string;
    function CanBindPort(const APort: Integer): Boolean;overload;
    function CanBindPort: Boolean;overload;
    function GetPort: Word;
    procedure SetPort(const Value: Word);
    function GetActive: Boolean;
    procedure Start;
    procedure Stop;
    function GetOnStarting: TNotifyEvent;
    procedure SetOnStarting(const Value: TNotifyEvent);
    function GetOnStarted: TNotifyEvent;
    procedure SetOnStarted(const Value: TNotifyEvent);
    function GetOnStopping: TNotifyEvent;
    procedure SetOnStopping(const Value: TNotifyEvent);
    function GetOnStopped: TNotifyEvent;
    procedure SetOnStopped(const Value: TNotifyEvent);
    function GetOnError: TNotifyEvent;
    procedure SetOnError(const Value: TNotifyEvent);
    function GetOnDestroy: TNotifyEvent;
    procedure SetOnDestroy(const Value: TNotifyEvent);

    property IndyVersion: string read GetIndyVersion;
    property SessionID: string read GetSessionID;
    property Port: Word read GetPort write SetPort;
    property Active: Boolean read GetActive;
    property OnStarting: TNotifyEvent read GetOnStarting write SetOnStarting;
    property OnStarted: TNotifyEvent read GetOnStarted write SetOnStarted;
    property OnStopping: TNotifyEvent read GetOnStopping write SetOnStopping;
    property OnStopped: TNotifyEvent read GetOnStopped write SetOnStopped;
    property OnError: TNotifyEvent read GetOnError write SetOnError;
    property OnDestroy: TNotifyEvent read GetOnDestroy write SetOnDestroy;
  end;

implementation
end.
