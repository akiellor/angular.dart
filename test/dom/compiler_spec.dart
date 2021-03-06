library compiler_spec;

import '../_specs.dart';
import 'dart:mirrors';


main() {

  describe('dte.compiler', () {
    Compiler $compile;
    Injector injector;
    Scope $rootScope;

    beforeEach(module((AngularModule module) {
      module
        ..type(TabComponent)
        ..type(PublishTypesAttrDirective)
        ..type(PaneComponent)
        ..type(SimpleTranscludeInAttachAttrDirective)
        ..type(IncludeTranscludeAttrDirective)
        ..type(LocalAttrDirective);
      return (Injector _injector) {
        injector = _injector;
        $compile = injector.get(Compiler);
        $rootScope = injector.get(Scope);
      };
    }));

    it('should compile basic hello world', inject(() {
      var element = $('<div ng-bind="name"></div>');
      var template = $compile(element);

      $rootScope['name'] = 'angular';
      template(injector, element);

      expect(element.text()).toEqual('');
      $rootScope.$digest();
      expect(element.text()).toEqual('angular');
    }));

    it('should not throw on an empty list', inject(() {
      $compile([]);
    }));

    it('should compile a directive in a child', inject(() {
      var element = $('<div><div ng-bind="name"></div></div>');
      var template = $compile(element);

      $rootScope['name'] = 'angular';


      template(injector, element);

      expect(element.text()).toEqual('');
      $rootScope.$digest();
      expect(element.text()).toEqual('angular');
    }));


    it('should compile repeater', inject(() {
      var element = $('<div><div ng-repeat="item in items" ng-bind="item"></div></div>');
      var template = $compile(element);

      $rootScope.items = ['A', 'b'];
      template(injector, element);

      expect(element.text()).toEqual('');
      // TODO(deboer): Digest twice until we have dirty checking in the scope.
      $rootScope.$digest();
      $rootScope.$digest();
      expect(element.text()).toEqual('Ab');

      $rootScope.items = [];
      $rootScope.$digest();
      expect(element.html()).toEqual('<!--ANCHOR: [ng-repeat]=item in items-->');
    }));

    it('should compile repeater with children', inject((Compiler $compile) {
      var element = $('<div><div ng-repeat="item in items"><div ng-bind="item"></div></div></div>');
      var template = $compile(element);

      $rootScope.items = ['A', 'b'];
      template(injector, element);

      expect(element.text()).toEqual('');
      // TODO(deboer): Digest twice until we have dirty checking in the scope.
      $rootScope.$digest();
      $rootScope.$digest();
      expect(element.text()).toEqual('Ab');

      $rootScope.items = [];
      $rootScope.$digest();
      expect(element.html()).toEqual('<!--ANCHOR: [ng-repeat]=item in items-->');
    }));


    it('should compile text', inject((Compiler $compile) {
      var element = $('<div>{{name}}<span>!</span></div>').contents();
      element.remove(null);
      print('test');

      var template = $compile(element);

      $rootScope.name = 'OK';
      var block = template(injector, element);

      element = $(block.elements);

      expect(element.text()).toEqual('!');
      $rootScope.$digest();
      expect(element.text()).toEqual('OK!');
    }));


    it('should compile nested repeater', inject((Compiler $compile) {
      var element = $(
          '<div>' +
            '<ul ng-repeat="lis in uls">' +
               '<li ng-repeat="li in lis">{{li}}</li>' +
            '</ul>' +
          '</div>');
      var template = $compile(element);

      $rootScope.uls = [['A'], ['b']];
      template(injector, element);

      expect(element.text()).toEqual('');
      $rootScope.$digest();
      expect(element.text()).toEqual('Ab');
    }));


    describe("interpolation", () {
      it('should interpolate attribute nodes', inject(() {
        var element = $('<div test="{{name}}"></div>');
        var template = $compile(element);

        $rootScope.name = 'angular';
        template(injector, element);

        $rootScope.$digest();
        expect(element.attr('test')).toEqual('angular');
      }));


      it('should interpolate text nodes', inject(() {
        var element = $('<div>{{name}}</div>');
        var template = $compile(element);

        $rootScope.name = 'angular';
        template(injector, element);

        expect(element.text()).toEqual('');
        $rootScope.$digest();
        expect(element.text()).toEqual('angular');
      }));
    });


    describe('components', () {
      beforeEach(module((AngularModule module) {
        module.type(SimpleComponent);
        module.type(CamelCaseMapComponent);
        module.type(IoComponent);
        module.type(IoControllerComponent);
        module.type(UnpublishedIoControllerComponent);
        module.type(IncorrectMappingComponent);
        module.type(NonAssignableMappingComponent);
        module.type(ParentExpressionComponent);
        module.type(PublishMeComponent);
        module.type(PublishMeDirective);
        module.type(LogComponent);
        module.type(AttachDetachComponent);
        module.type(SimpleComponent);
      }));

      it('should select on element', async(inject((Zone zone) {
        var element = $(r'<div><simple></simple></div>');

        zone.run(() {
          BlockFactory blockFactory = $compile(element);
          Block block = blockFactory(injector, element);
        });

        microLeap();
        expect(element.textWithShadow()).toEqual('INNER_1()');
      })));

      it('should create a simple component', async(inject((Zone zone) {
        $rootScope.name = 'OUTTER';
        $rootScope.sep = '-';
        var element = $(r'<div>{{name}}{{sep}}{{$id}}:<simple>{{name}}{{sep}}{{$id}}</simple></div>');

        zone.run(() {
          BlockFactory blockFactory = $compile(element);
          Block block = blockFactory(injector, element);
        });

        microLeap();
        expect(element.textWithShadow()).toEqual('OUTTER-_0:INNER_1(OUTTER-_0)');
      })));

      it('should create a component that can access parent scope', async(inject((Zone zone) {
        $rootScope.fromParent = "should not be used";
        $rootScope.val = "poof";
        var element = $('<parent-expression from-parent=val></parent-expression>');

        zone.run(() =>
          $compile(element)(injector, element));

        microLeap();
        expect(renderedText(element)).toEqual('inside poof');
      })));

      it('should behave nicely if a mapped attribute is missing', async(inject((Zone zone) {
        var element = $('<parent-expression></parent-expression>');
        zone.run(() =>
          $compile(element)(injector, element));

        microLeap();
        expect(renderedText(element)).toEqual('inside ');
      })));

      it('should behave nicely if a mapped attribute evals to null', async(inject((Zone zone) {
        $rootScope.val = null;
        var element = $('<parent-expression fromParent=val></parent-expression>');
        zone.run(() =>
          $compile(element)(injector, element));

        microLeap();
        expect(renderedText(element)).toEqual('inside ');
      })));

      it('should create a component with I/O', async(inject(() {
        var element = $(r'<div><io attr="A" expr="name" ondone="done=true"></io></div>');
        $compile(element)(injector, element);
        microLeap();

        $rootScope.name = 'misko';
        $rootScope.$apply();
        var component = $rootScope.ioComponent;
        expect(component.scope.name).toEqual(null);
        expect(component.scope.attr).toEqual('A');
        expect(component.scope.expr).toEqual('misko');
        component.scope.expr = 'angular';
        $rootScope.$apply();
        expect($rootScope.name).toEqual('angular');
        expect($rootScope.done).toEqual(null);
        component.scope.ondone();
        expect($rootScope.done).toEqual(true);
      })));

      it('should create a component with I/O and "=" binding value should be available', async(inject(() {
        $rootScope.name = 'misko';
        var element = $(r'<div><io attr="A" expr="name" ondone="done=true"></io></div>');
        $compile(element)(injector, element);
        microLeap();

        var component = $rootScope.ioComponent;
        $rootScope.$apply();
        expect(component.scope.expr).toEqual('misko');
        component.scope.expr = 'angular';
        $rootScope.$apply();
        expect($rootScope.name).toEqual('angular');
      })));

      it('should create a component with I/O bound to controller and "=" binding value should be available', async(inject(() {
        $rootScope.done = false;
        var element = $(r'<div><io-controller attr="A" expr="name" once="name" ondone="done=true"></io-controller></div>');


        expect(injector).toBeDefined();
        $compile(element)(injector, element);
        microLeap();

        IoControllerComponent component = $rootScope.ioComponent;

        expect(component.expr).toEqual(null);
        expect(component.exprOnce).toEqual(null);
        expect(component.attr).toEqual('A');
        $rootScope.$apply();

        $rootScope.name = 'misko';
        $rootScope.$apply();
        expect(component.expr).toEqual('misko');
        expect(component.exprOnce).toEqual('misko');

        $rootScope.name = 'igor';
        $rootScope.$apply();
        expect(component.expr).toEqual('igor');
        expect(component.exprOnce).toEqual('misko');

        component.expr = 'angular';
        $rootScope.$apply();
        expect($rootScope.name).toEqual('angular');

        expect($rootScope.done).toEqual(false);
        component.onDone();
        expect($rootScope.done).toEqual(true);

        // Should be noop
        component.onOptional();
      })));

      it('should create a map attribute to controller', async(() {
        var element = $(r'<div><io-controller attr="{{name}}"></io-controller></div>');
        $compile(element)(injector, element);
        microLeap();

        IoControllerComponent component = $rootScope.ioComponent;

        $rootScope.name = 'misko';
        $rootScope.$apply();
        expect(component.attr).toEqual('misko');

        $rootScope.name = 'james';
        $rootScope.$apply();
        expect(component.attr).toEqual('james');
      }));

      it('should create a unpublished component with I/O bound to controller and "=" binding value should be available', async(() {
        $rootScope.name = 'misko';
        $rootScope.done = false;
        var element = $(r'<div><unpublished-io-controller attr="A" expr="name" ondone="done=true"></unpublished-io-controller></div>');
        $compile(element)(injector, element);
        microLeap();

        UnpublishedIoControllerComponent component = $rootScope.ioComponent;
        $rootScope.$apply();
        expect(component.attr).toEqual('A');
        expect(component.expr).toEqual('misko');
        component.expr = 'angular';
        $rootScope.$apply();
        expect($rootScope.name).toEqual('angular');

        expect($rootScope.done).toEqual(false);
        component.onDone();
        expect($rootScope.done).toEqual(true);

        // Should be noop
        component.onOptional();
      }));

      it('should error on incorrect mapping', async(inject(() {
        expect(() {
          var element = $(r'<div><incorrect-mapping></incorrect-mapping</div>');
          $compile(element)(injector, element);
        }).toThrow("Unknown mapping 'foo\' for attribute 'attr'.");
      })));

      it('should error on non-asignable-mapping', async(inject(() {
        expect(() {
          var element = $(r'<div><non-assignable-mapping></non-assignable-mapping</div>');
          $compile(element)(injector, element);
        }).toThrow("Expression '1+2' is not assignable in mapping '@1+2' for attribute 'attr'.");
      })));

      it('should expose mapped attributes as camel case', async(inject(() {
        var element = $('<camel-case-map camel-case=G></camel-case-map>');
        $compile(element)(injector, element);
        microLeap();
        $rootScope.$apply();
        var componentScope = $rootScope.camelCase;
        expect(componentScope.camelCase).toEqual('G');
      })));

      it('should throw an exception if required directive is missing', async(inject((Compiler $compile, Scope $rootScope, Injector injector) {
        try {
          var element = $('<tab local><pane></pane><pane local></pane></tab>');
          $compile(element)(injector, element);
        } catch (e) {
          var text = '$e';
          expect(text).toContain('No provider found for');
          expect(text).toContain('(resolving ');
          expect(text).toContain('LocalAttrDirective');
        }
      })));

      it('should publish component controller into the scope', async(inject((Zone zone) {
        var element = $(r'<div><publish-me></publish-me></div>');
        zone.run(() =>
        $compile(element)(injector, element));

        microLeap();
        expect(element.textWithShadow()).toEqual('WORKED');
      })));

      it('should publish directive controller into the scope', async(inject((Zone zone) {
        var element = $(r'<div><div publish-me>{{ctrlName.value}}</div></div>');
        zone.run(() =>
        $compile(element)(injector, element));

        microLeap();
        expect(element.text()).toEqual('WORKED');
      })));

      it('should "publish" controller to injector under provided publishTypes', inject(() {
        var element = $(r'<div publish-types></div>');
        $compile(element)(injector, element);
        expect(PublishTypesAttrDirective._injector.get(PublishTypesAttrDirective)).
            toBe(PublishTypesAttrDirective._injector.get(PublishTypesDirectiveSuperType));
      }));

      it('should allow repeaters over controllers', async(inject((Logger logger) {
        var element = $(r'<log ng-repeat="i in [1, 2]"></log>');
        $compile(element)(injector, element);
        $rootScope.$apply();
        microLeap();

        expect(logger.length).toEqual(2);
      })));

      describe('lifecycle', () {
        it('should fire attach/detach methods', async(inject((Logger logger) {
          var scope = $rootScope.$new();
          var element = $('<attach-detach></attach-detach>');
          $compile(element)(injector.createChild([new Module()..value(Scope, scope)]), element);
          expect(logger).toEqual(['new']);

          microLeap();
          $rootScope.$digest();
          expect(logger).toEqual(['new', 'attach']);

          scope.$destroy();
          expect(logger).toEqual(['new', 'attach', 'detach']);
        })));
      });
    });

    describe('controller scoping', () {

      it('should make controllers available to sibling and child controllers', async(inject((Compiler $compile, Scope $rootScope, Logger log, Injector injector) {
        var element = $('<tab local><pane local></pane><pane local></pane></tab>');
        $compile(element)(injector, element);
        microLeap();

        expect(log.result()).toEqual('TabComponent-0; LocalAttrDirective-0; PaneComponent-1; LocalAttrDirective-0; PaneComponent-2; LocalAttrDirective-0');
      })));

      it('should reuse controllers for transclusions', async(inject((Compiler $compile, Scope $rootScope, Logger log, Injector injector) {
        var element = $('<div simple-transclude-in-attach include-transclude>block</div>');
        $compile(element)(injector, element);
        microLeap();

        $rootScope.$apply();
        expect(log.result()).toEqual('IncludeTransclude; SimpleTransclude');
      })));

    });
  });
}

@NgComponent(
    selector: 'tab',
    visibility: NgDirective.DIRECT_CHILDREN_VISIBILITY)
class TabComponent {
  int id = 0;
  Logger log;
  LocalAttrDirective local;
  TabComponent(Logger this.log, LocalAttrDirective this.local, Scope scope) {
    log('TabComponent-${id++}');
    local.ping();
  }
}

@NgComponent(selector: 'pane')
class PaneComponent {
  TabComponent tabComponent;
  LocalAttrDirective localDirective;
  Logger log;
  PaneComponent(TabComponent this.tabComponent, LocalAttrDirective this.localDirective, Logger this.log, Scope scope) {
    log('PaneComponent-${tabComponent.id++}');
    localDirective.ping();
  }
}

@NgDirective(
    selector: '[local]',
    visibility: NgDirective.LOCAL_VISIBILITY)
class LocalAttrDirective {
  int id = 0;
  Logger log;
  LocalAttrDirective(Logger this.log);
  ping() {
    log('LocalAttrDirective-${id++}');
  }
}

@NgDirective(
    selector: '[simple-transclude-in-attach]',
    visibility: NgDirective.CHILDREN_VISIBILITY, children: NgAnnotation.TRANSCLUDE_CHILDREN)
class SimpleTranscludeInAttachAttrDirective {
  SimpleTranscludeInAttachAttrDirective(BlockHole blockHole, BoundBlockFactory boundBlockFactory, Logger log, Scope scope) {
    scope.$evalAsync(() {
      var block = boundBlockFactory(scope);
      block.insertAfter(blockHole);
      log('SimpleTransclude');
    });
  }
}

@NgDirective(selector: '[include-transclude]')
class IncludeTranscludeAttrDirective {
  IncludeTranscludeAttrDirective(SimpleTranscludeInAttachAttrDirective simple, Logger log) {
    log('IncludeTransclude');
  }
}

class PublishTypesDirectiveSuperType {
}

@NgDirective(
    selector: '[publish-types]',
    publishTypes: const [PublishTypesDirectiveSuperType])
class PublishTypesAttrDirective implements PublishTypesDirectiveSuperType {
  static Injector _injector;
  PublishTypesAttrDirective(Injector injector) {
    _injector = injector;
  }
}

@NgComponent(
    selector: 'simple',
    template: r'{{name}}{{sep}}{{$id}}(<content>SHADOW-CONTENT</content>)'
)
class SimpleComponent {
  SimpleComponent(Scope scope) {
    scope.name = 'INNER';
  }
}

@NgComponent(
    selector: 'io',
    template: r'<content></content>',
    map: const {
        'attr': '@',
        'expr': '=',
        'ondone': '&',
    }
)
class IoComponent {
  Scope scope;
  IoComponent(Scope scope) {
    this.scope = scope;
    scope.$root.ioComponent = this;
  }
}

@NgComponent(
    selector: 'io-controller',
    template: r'<content></content>',
    publishAs: 'ctrl',
    map: const {
        'attr': '@ctrl.attr',
        'expr': '=ctrl.expr',
        'once': '!.exprOnce',
        'ondone': '&ctrl.onDone',
        'onOptional': '&ctrl.onOptional'
    }
)
class IoControllerComponent {
  Scope scope;
  var attr;
  var expr;
  var exprOnce;
  var onDone;
  var onOptional;
  IoControllerComponent(Scope scope) {
    this.scope = scope;
    scope.$root.ioComponent = this;
  }
}

@NgComponent(
    selector: 'unpublished-io-controller',
    template: r'<content></content>',
    map: const {
        'attr': '@.attr',
        'expr': '=.expr',
        'ondone': '&.onDone',
        'onOptional': '&.onOptional'
    }
)
class UnpublishedIoControllerComponent {
  Scope scope;
  var attr;
  var expr;
  var exprOnce;
  var onDone;
  var onOptional;
  UnpublishedIoControllerComponent(Scope scope) {
    this.scope = scope;
    scope.$root.ioComponent = this;
  }
}

@NgComponent(
    selector: 'incorrect-mapping',
    template: r'<content></content>',
    map: const { 'attr': 'foo' })
class IncorrectMappingComponent { }

@NgComponent(
    selector: 'non-assignable-mapping',
    template: r'<content></content>',
    map: const { 'attr': '@1+2' })
class NonAssignableMappingComponent { }

@NgComponent(
    selector: 'camel-case-map',
    map: const {
      'camelCase': '@',
    }
)
class CamelCaseMapComponent {
  CamelCaseMapComponent(Scope scope) {
    scope.$root.camelCase = scope;
  }
}

@NgComponent(
    selector: 'parent-expression',
    template: '<div>inside {{fromParent()}}</div>',
    map: const {
      'fromParent': '&',
    }
)
class ParentExpressionComponent {
}

@NgComponent(
    selector: 'publish-me',
    template: r'<content>{{ctrlName.value}}</content>',
    publishAs: 'ctrlName'
)
class PublishMeComponent {
  String value = 'WORKED';
}


@NgDirective (
    selector: '[publish-me]',
    publishAs: 'ctrlName'
)
class PublishMeDirective {
  String value = 'WORKED';
}


@NgComponent(
    selector: 'log',
    template: r'<content></content>',
    publishAs: 'ctrlName'
)
class LogComponent {
  LogComponent(Scope scope, Logger logger) {
    logger(scope);
  }
}

@NgComponent(
    selector: 'attach-detach',
    template: r'<content></content>'
)
class AttachDetachComponent implements NgAttachAware, NgDetachAware {
  Logger logger;

  AttachDetachComponent(Logger this.logger) {
    logger('new');
  }

  attach() => logger('attach');
  detach() => logger('detach');
}
